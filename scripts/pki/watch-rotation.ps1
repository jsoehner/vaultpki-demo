<#
.SYNOPSIS
    Monitors certificate rotation for the Vault PKI demo in real-time.
.PARAMETER Domain
    The server name / SNI domain (default: test.example.com).
.PARAMETER Port
    The HTTPS port (default: 8443).
.PARAMETER HostName
    The target host (default: 127.0.0.1).
.PARAMETER IntervalSeconds
    Interval between polling attempts in seconds (default: 5).
.EXAMPLE
    .\watch-rotation.ps1
.EXAMPLE
    .\watch-rotation.ps1 -Domain test.example.com -Port 8443 -IntervalSeconds 3
#>
[CmdletBinding()]
param(
    [string]$Domain = "test.example.com",
    [int]$Port = 8443,
    [string]$HostName = "127.0.0.1",
    [int]$IntervalSeconds = 5
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Watching Certificate for $Domain on port $Port" -ForegroundColor Cyan
Write-Host " Certificates are configured to have a TTL of 1m." -ForegroundColor Cyan
Write-Host " Vault Agent should rotate them approximately every 40s." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$prevSerial = ""

function Get-RemoteCertificate {
    param(
        [string]$targetHost,
        [int]$targetPort,
        [string]$sniDomain
    )
    
    $tcp = $null
    $ssl = $null
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcp.ConnectAsync($targetHost, $targetPort)
        if (-not $connectTask.Wait(3000)) {
            return $null
        }
        $ssl = New-Object System.Net.Security.SslStream(
            $tcp.GetStream(),
            $false,
            { param($sender, $certificate, $chain, $sslPolicyErrors) $true }
        )
        $ssl.AuthenticateAsClient($sniDomain)
        if ($ssl.RemoteCertificate) {
            return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
        }
    } catch {
        return $null
    } finally {
        if ($ssl) { $ssl.Dispose() }
        if ($tcp) { $tcp.Dispose() }
    }
    return $null
}

try {
    while ($true) {
        $timeStr = (Get-Date).ToString("HH:mm:ss")
        $cert = Get-RemoteCertificate -targetHost $HostName -targetPort $Port -sniDomain $Domain

        if (-not $cert) {
            Write-Host "$timeStr - Could not connect to ${HostName}:${Port}" -ForegroundColor Red
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }

        $serial = $cert.SerialNumber
        $notAfter = "Not After : $($cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss UTC'))"

        if ($serial -ne $prevSerial) {
            Write-Host "--------------------------------------------------" -ForegroundColor Green
            Write-Host "🔄 CERTIFICATE ROTATED at $timeStr" -ForegroundColor Green
            Write-Host "   New Serial:   $serial" -ForegroundColor Yellow
            Write-Host "   $notAfter" -ForegroundColor Yellow
            Write-Host "   Subject:      $($cert.Subject)" -ForegroundColor DarkGray
            Write-Host "   Issuer:       $($cert.Issuer)" -ForegroundColor DarkGray
            Write-Host "--------------------------------------------------" -ForegroundColor Green
            $prevSerial = $serial
        } else {
            Write-Host "$timeStr - Serial: $serial (No change)" -ForegroundColor Gray
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
} catch [System.Management.Automation.PipelineStoppedException] {
    # Clean exit on Ctrl+C in PowerShell
}
