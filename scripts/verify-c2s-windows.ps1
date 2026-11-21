# Run after connecting/disconnecting OpenVPN GUI in the FIVE-node model.
[CmdletBinding()]
param([ValidateSet('Connected', 'Disconnected')][string]$ExpectedState = 'Connected')
$ErrorActionPreference = 'Stop'
$failedChecks = 0
function Record-Check([bool]$Ok, [string]$Description) {
    if ($Ok) { Write-Host "[PASS] $Description" } else {
        Write-Host "[FAIL] $Description"; $script:failedChecks++
    }
}
$vpnAddresses = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '10.8.0.*' })
$hqRoutes = @(Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq '10.74.10.0/24' })
$vpnRoutes = @($hqRoutes | Where-Object { $_.InterfaceIndex -in $vpnAddresses.InterfaceIndex })
if ($ExpectedState -eq 'Connected') {
    Record-Check ($vpnAddresses.Count -gt 0) 'VPN IPv4 address in 10.8.0.0/24'
    Record-Check ($vpnRoutes.Count -gt 0) 'HQ subnet route uses the VPN interface'
} else {
    Record-Check ($vpnAddresses.Count -eq 0) 'VPN IPv4 address removed'
    Record-Check ($hqRoutes.Count -eq 0) 'HQ subnet route removed'
}
# curl.exe bypasses proxies and imposes a bounded network timeout.
$httpCode = & curl.exe --noproxy '*' -s --connect-timeout 3 --max-time 6 -o NUL -w '%{http_code}' http://10.74.10.50/
$curlExit = $LASTEXITCODE
if ($ExpectedState -eq 'Connected') {
    Record-Check ($curlExit -eq 0 -and $httpCode -eq '200') 'HQ Portal returns HTTP 200'
} else {
    Record-Check ($curlExit -in 7, 28 -and $httpCode -eq '000') 'HQ Portal cannot be reached'
}
Write-Host 'This checks connectivity and routes; confirm authentication/cipher in the OpenVPN logs.'
if ($failedChecks -gt 0) { exit 1 }
exit 0
