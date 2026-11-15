<#
.SYNOPSIS
    Manual PKI setup script for HashiCorp Vault demo container.
.DESCRIPTION
    Initializes and unseals Vault (with ML-DSA-65 post-quantum CA generation and
    graceful RSA-4096 fallback), signs intermediate certificates, creates PKI roles,
    and configures AppRole credentials for the Vault Agent.
.EXAMPLE
    .\setup-pki.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "Waiting for Vault to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Check if initialized
$statusRaw = (& docker exec vault-pki-demo vault status -format=json 2>$null)
$status = $null
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
    try {
        $status = $statusRaw | ConvertFrom-Json
    } catch {}
}

if ($status -and $status.initialized -eq $true) {
    Write-Host "Vault is already initialized." -ForegroundColor Green
    
    $keysFile = ""
    if (Test-Path "vault-keys.txt") {
        $keysFile = "vault-keys.txt"
    } elseif (Test-Path "config/vault-keys.txt") {
        $keysFile = "config/vault-keys.txt"
    }

    if ($keysFile) {
        $unsealLine = Get-Content $keysFile | Where-Object { $_ -match "^UNSEAL_KEY=(.*)$" }
        if ($unsealLine -match "^UNSEAL_KEY=(.*)$") {
            $unsealKey = $Matches[1].Trim()
            Write-Host "Unsealing..." -ForegroundColor Yellow
            & docker exec vault-pki-demo vault operator unseal $unsealKey
        }
    } else {
        Write-Host "Please unseal manually." -ForegroundColor Yellow
    }
    exit 0
}

Write-Host "Initializing Vault..." -ForegroundColor Cyan
$initRaw = (& docker exec vault-pki-demo vault operator init -key-shares=1 -key-threshold=1 -format=json)
$initJson = $initRaw | ConvertFrom-Json
$unsealKey = $initJson.unseal_keys_b64[0]
$rootToken = $initJson.root_token

if (-not (Test-Path "config")) {
    New-Item -ItemType Directory -Path "config" -Force | Out-Null
}
"UNSEAL_KEY=$unsealKey`nROOT_TOKEN=$rootToken" | Set-Content -Path "config/vault-keys.txt" -NoNewline

Write-Host "Unsealing Vault..." -ForegroundColor Cyan
& docker exec vault-pki-demo vault operator unseal $unsealKey

Write-Host "Logging in..." -ForegroundColor Cyan
& docker exec vault-pki-demo vault login $rootToken

Write-Host "Running PKI setup..." -ForegroundColor Cyan

# Enable Root CA
& docker exec vault-pki-demo vault secrets enable -path=pki pki 2>$null
& docker exec vault-pki-demo vault secrets tune -max-lease-ttl=87600h pki 2>$null

# Try ML-DSA-65, fallback to RSA if unsupported
$usingFallback = $false
$rootOut = (& docker exec vault-pki-demo vault write pki/root/generate/internal `
    common_name="My Organization Root CA" `
    issuer_name="root-2026" `
    ttl=87600h key_type=ml-dsa-65 2>&1)

if ($LASTEXITCODE -ne 0) {
    if ($rootOut -match "unsupported" -or $rootOut -match "invalid" -or $rootOut -match "Error") {
        Write-Host "ML-DSA-65 key type is not supported by this Vault instance. Falling back to RSA 4096..." -ForegroundColor Yellow
        & docker exec vault-pki-demo vault write pki/root/generate/internal `
            common_name="My Organization Root CA" `
            issuer_name="root-2026" `
            ttl=87600h key_type=rsa key_bits=4096
        $usingFallback = $true
    } else {
        Write-Error "Failed to generate root CA: $rootOut"
        exit 1
    }
}

& docker exec vault-pki-demo vault write pki/config/urls `
    issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" `
    crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

# Enable Intermediate CA
& docker exec vault-pki-demo vault secrets enable -path=pki_int pki 2>$null
& docker exec vault-pki-demo vault secrets tune -max-lease-ttl=43800h pki_int 2>$null

if ($usingFallback) {
    $intRaw = & docker exec vault-pki-demo vault write -format=json pki_int/intermediate/generate/internal `
        common_name="My Organization Intermediate CA" `
        issuer_name="intermediate-2026" `
        key_type=rsa key_bits=4096
} else {
    $intRaw = & docker exec vault-pki-demo vault write -format=json pki_int/intermediate/generate/internal `
        common_name="My Organization Intermediate CA" `
        issuer_name="intermediate-2026" `
        key_type=ml-dsa-65
}

$intJson = $intRaw | ConvertFrom-Json
$intJson.data.csr | Set-Content -Path "intermediate.csr" -NoNewline
& docker cp intermediate.csr vault-pki-demo:/tmp/intermediate.csr

# Sign Intermediate CA
$signedRaw = & docker exec vault-pki-demo vault write -format=json pki/root/sign-intermediate `
    csr=@/tmp/intermediate.csr `
    format=pem_bundle `
    ttl=43800h
$signedJson = $signedRaw | ConvertFrom-Json
$signedJson.data.certificate | Set-Content -Path "intermediate.cert.pem" -NoNewline

& docker cp intermediate.cert.pem vault-pki-demo:/tmp/intermediate.cert.pem
& docker exec vault-pki-demo vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem

& docker exec vault-pki-demo vault write pki_int/config/urls `
    issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" `
    crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl" `
    ocsp_servers="http://127.0.0.1:8200/v1/pki_int/ocsp"

# Create a sample role
if ($usingFallback) {
    & docker exec vault-pki-demo vault write pki_int/roles/web-server `
        allowed_domains="example.com" `
        allow_subdomains=true `
        max_ttl=8760h key_type=rsa key_bits=2048 `
        require_cn=true allow_ip_sans=true `
        server_flag=true client_flag=false
} else {
    & docker exec vault-pki-demo vault write pki_int/roles/web-server `
        allowed_domains="example.com" `
        allow_subdomains=true `
        max_ttl=8760h key_type=ml-dsa-65 `
        require_cn=true allow_ip_sans=true `
        server_flag=true client_flag=false
}

Write-Host "Configuring AppRole for Vault Agent..." -ForegroundColor Cyan
& docker exec vault-pki-demo vault auth enable approle 2>$null

& docker exec vault-pki-demo sh -c 'vault policy write cert-issuer - <<EOF
path "pki_int/issue/web-server" {
  capabilities = ["create", "update"]
}
EOF'

& docker exec vault-pki-demo vault write auth/approle/role/web-server-role `
    policies="cert-issuer" `
    secret_id_ttl=720h `
    token_num_uses=0 `
    token_ttl=1h `
    token_max_ttl=4h `
    secret_id_num_uses=0

if (-not (Test-Path "agent")) {
    New-Item -ItemType Directory -Path "agent" -Force | Out-Null
}

$roleIdRaw = & docker exec vault-pki-demo vault read -format=json auth/approle/role/web-server-role/role-id
$roleIdJson = $roleIdRaw | ConvertFrom-Json
$roleIdJson.data.role_id | Set-Content -Path "./agent/roleid" -NoNewline

$secretIdRaw = & docker exec vault-pki-demo vault write -format=json -f auth/approle/role/web-server-role/secret-id
$secretIdJson = $secretIdRaw | ConvertFrom-Json
$secretIdJson.data.secret_id | Set-Content -Path "./agent/secretid" -NoNewline

Write-Host "Setup complete! You can issue certificates now." -ForegroundColor Green
