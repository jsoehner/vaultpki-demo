<#
.SYNOPSIS
    Fetches and displays certificate details from the Vault PKI demo NGINX server.
.PARAMETER Domain
    The server name / SNI domain (default: test.example.com).
.PARAMETER Port
    The HTTPS port (default: 8443).
.PARAMETER HostName
    The target host (default: 127.0.0.1).
.EXAMPLE
    .\check-cert.ps1
.EXAMPLE
    .\check-cert.ps1 -Domain test.example.com -Port 8443
#>
[CmdletBinding()]
param(
    [string]$Domain = "test.example.com",
    [int]$Port = 8443,
    [string]$HostName = "127.0.0.1"
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Fetching Certificate for $Domain on port $Port" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$tcp = $null
$ssl = $null
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $connectTask = $tcp.ConnectAsync($HostName, $Port)
    if (-not $connectTask.Wait(5000)) {
        throw "Connection timed out to ${HostName}:${Port}"
    }

    $ssl = New-Object System.Net.Security.SslStream(
        $tcp.GetStream(),
        $false,
        { param($sender, $certificate, $chain, $sslPolicyErrors) $true }
    )
    $ssl.AuthenticateAsClient($Domain)
    
    if ($ssl.RemoteCertificate) {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
        
        Write-Host "Subject:           $($cert.Subject)" -ForegroundColor Green
        Write-Host "Issuer:            $($cert.Issuer)" -ForegroundColor Green
        Write-Host "Serial Number:     $($cert.SerialNumber)" -ForegroundColor Yellow
        Write-Host "Thumbprint:        $($cert.Thumbprint)" -ForegroundColor Yellow
        Write-Host "Not Before:        $($cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss UTC'))"
        Write-Host "Not After:         $($cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss UTC'))"
        Write-Host "Signature Alg:     $($cert.SignatureAlgorithm.FriendlyName)"
        Write-Host "Key Algorithm:     $($cert.GetKeyAlgorithm())"
        
        Write-Host "`nExtensions:" -ForegroundColor Cyan
        foreach ($ext in $cert.Extensions) {
            $formatted = $ext.Format($false)
            Write-Host "  $($ext.Oid.FriendlyName) ($($ext.Oid.Value)): $formatted"
        }
    } else {
        Write-Error "No certificate returned from ${HostName}:${Port}"
    }
} catch {
    Write-Error "Failed to connect or retrieve certificate: $_"
} finally {
    if ($ssl) { $ssl.Dispose() }
    if ($tcp) { $tcp.Dispose() }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Done" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
