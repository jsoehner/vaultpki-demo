<#
.SYNOPSIS
    HashiCorp Vault PKI Demo Orchestrator for Windows PowerShell.
.DESCRIPTION
    Stops any existing containers, spins up the Vault PKI stack using Docker Compose,
    waits for the automated vault-init container to complete PKI setup, and prints
    access information and endpoint status.
.PARAMETER MaxWaitSeconds
    Maximum time in seconds to wait for vault-init to complete (default: 30).
.PARAMETER RegistryPrefix
    Optional container registry prefix (e.g. 'oss.jsigroup.local:8080/'). If omitted,
    checks trusted registry availability and falls back gracefully to Docker Hub.
.EXAMPLE
    .\run_demo.ps1
.EXAMPLE
    .\run_demo.ps1 -MaxWaitSeconds 45
#>
[CmdletBinding()]
param(
    [int]$MaxWaitSeconds = 30,
    [string]$RegistryPrefix = ""
)

$ErrorActionPreference = "Stop"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "       HashiCorp Vault PKI Demo Orchestrator          " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# Check for docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Error: docker is required but not installed or not in PATH." -ForegroundColor Red
    exit 1
}

# Determine compose command
$UseDockerComposeStandalone = $false
try {
    $null = & docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed"
    }
} catch {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $UseDockerComposeStandalone = $true
    } else {
        Write-Host "Error: docker compose plugin or docker-compose is required but not installed." -ForegroundColor Red
        exit 1
    }
}

function Invoke-Compose {
    if ($UseDockerComposeStandalone) {
        & docker-compose @args
    } else {
        & docker compose @args
    }
}

# Determine and validate image registry prefix
if ($RegistryPrefix) {
    $env:REGISTRY_PREFIX = $RegistryPrefix
} elseif (-not $env:REGISTRY_PREFIX) {
    # Check if trusted registry images exist locally or remotely
    $trustedPrefix = "oss.jsigroup.local:8080/"
    $trustedImage = "${trustedPrefix}hashicorp/vault:latest"
    $hasLocal = (& docker image inspect $trustedImage 2>$null)
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Using locally cached images from trusted registry prefix: $trustedPrefix" -ForegroundColor Green
        $env:REGISTRY_PREFIX = $trustedPrefix
    } else {
        $null = (& docker manifest inspect $trustedImage 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Verified trusted registry: $trustedPrefix" -ForegroundColor Green
            $env:REGISTRY_PREFIX = $trustedPrefix
        } else {
            Write-Host "[!] Note: Images not found on trusted registry 'oss.jsigroup.local:8080'." -ForegroundColor Yellow
            Write-Host "    Gracefully falling back to Docker Hub upstream images." -ForegroundColor Yellow
            $env:REGISTRY_PREFIX = ""
        }
    }
}

Write-Host "Stopping any existing containers and cleaning volumes..." -ForegroundColor Yellow
Invoke-Compose down -v

# If no vault keys exist, clean leftover raft storage so Vault can initialize fresh
if (-not (Test-Path "config/vault-keys.txt") -and (Test-Path "data")) {
    Remove-Item -Path "data/*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "certs/*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "agent/roleid", "agent/secretid" -Force -ErrorAction SilentlyContinue
}

Write-Host "Spinning up the Vault PKI stack..." -ForegroundColor Yellow
Invoke-Compose up -d

Write-Host "Waiting for Vault initialization and PKI configuration..." -ForegroundColor Yellow
$waitCount = 0
$initSuccess = $false

while ($waitCount -lt $MaxWaitSeconds) {
    $status = (& docker inspect -f '{{.State.Status}}' vault-init 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($status)) {
        $status = "not-found"
    } else {
        $status = $status.Trim()
    }

    if ($status -eq "exited") {
        $exitCodeRaw = (& docker inspect -f '{{.State.ExitCode}}' vault-init 2>$null)
        $exitCode = [int]($exitCodeRaw.Trim())
        if ($exitCode -eq 0) {
            $initSuccess = $true
            break
        } else {
            Write-Host ""
            Write-Host "vault-init service failed with exit code $exitCode" -ForegroundColor Red
            Write-Host "Showing vault-init logs:" -ForegroundColor Yellow
            & docker logs vault-init
            exit 1
        }
    } elseif ($status -eq "not-found") {
        Write-Host ""
        Write-Host "Error: vault-init container not found." -ForegroundColor Red
        exit 1
    }

    Start-Sleep -Seconds 1
    $waitCount++
    Write-Host -NoNewline "."
}
Write-Host ""

if (-not $initSuccess) {
    Write-Host "Error: Timeout waiting for vault-init to complete." -ForegroundColor Red
    exit 1
}

Write-Host "Initialization complete!" -ForegroundColor Green
Write-Host "Current container status:" -ForegroundColor Cyan
& docker ps --filter name=vault- --filter name=demo-nginx --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

Write-Host "`nDemo stack is running and healthy!" -ForegroundColor Green
Write-Host "Access the monitoring dashboard at: " -NoNewline -ForegroundColor Cyan
Write-Host "http://127.0.0.1:8080" -ForegroundColor Yellow
Write-Host "Access secure NGINX endpoint at:    " -NoNewline -ForegroundColor Cyan
Write-Host "https://127.0.0.1:8443" -ForegroundColor Yellow
Write-Host "Watch rotation logs with:          " -NoNewline -ForegroundColor Cyan
Write-Host ".\watch-rotation.ps1 (or ./watch-rotation.sh)" -ForegroundColor Yellow
Write-Host "Check generated certificate with:  " -NoNewline -ForegroundColor Cyan
Write-Host ".\check-cert.ps1 (or ./check-cert.sh)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan
