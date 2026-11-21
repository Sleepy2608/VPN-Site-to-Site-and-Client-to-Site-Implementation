# Run in the interactive Windows Remote-PC VM with the HQ-issued profile.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProfilePath,
    [string]$WanAdapterAlias
)

$ErrorActionPreference = 'Stop'
$profile = Get-Item -LiteralPath $ProfilePath
if ($profile.PSIsContainer -or $profile.Extension -ine '.ovpn') {
    throw 'Provide the client1.ovpn file issued by HQ-GW.'
}

$config = Get-Content -LiteralPath $profile.FullName -Raw
$header = ($config -split '(?m)^[ \t]*<ca>[ \t]*\r?$', 2)[0]
$remotes = [regex]::Matches($header, '(?m)^[ \t]*remote[ \t]+([^\r\n]+)')
if ($remotes.Count -ne 1 -or $remotes[0].Groups[1].Value.Trim() -notmatch '^172\.16\.1\.10\s+1194$' -or
    $header -notmatch '(?m)^[ \t]*proto[ \t]+udp[ \t]*\r?$' -or
    $header -notmatch '(?m)^[ \t]*remote-cert-tls[ \t]+server[ \t]*\r?$' -or
    $header -notmatch '(?m)^[ \t]*verify-x509-name[ \t]+hq-c2s-server[ \t]+name[ \t]*\r?$') {
    throw 'The profile must use HQ-GW UDP 1194 and verify the hq-c2s-server name.'
}
foreach ($block in 'ca', 'cert', 'key', 'tls-crypt') {
    if ($config -notmatch "(?m)^[ \t]*<$block>[ \t]*\r?$" -or $config -notmatch "(?m)^[ \t]*</$block>[ \t]*\r?$") {
        throw "The profile is missing its inline $block block. Use the file issued by HQ-GW."
    }
}

$installKey = Get-Item -LiteralPath 'HKLM:\SOFTWARE\OpenVPN' -ErrorAction SilentlyContinue
$installRoot = if ($installKey) { $installKey.GetValue('') }
if (!$installRoot) { $installRoot = Join-Path $env:ProgramFiles 'OpenVPN' }
$guiPath = Join-Path $installRoot 'bin\openvpn-gui.exe'
if (!(Test-Path -LiteralPath $guiPath -PathType Leaf)) {
    throw 'Install OpenVPN Community with OpenVPN GUI before running this script. https://openvpn.net/community/'
}

if ($WanAdapterAlias) {
    $adapter = Get-NetAdapter | Where-Object Name -eq $WanAdapterAlias
    if (!$adapter) { throw "No adapter named '$WanAdapterAlias'. Check Get-NetAdapter." }
    $interfaceIndex = $adapter.ifIndex
    $defaultRoute = Get-NetRoute -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object DestinationPrefix -eq '0.0.0.0/0'
    if ($defaultRoute) {
        throw 'The selected adapter has a default gateway. Select the isolated WAN-Net adapter.'
    }
    $addresses = Get-NetIPAddress -AddressFamily IPv4
    $assigned = $addresses | Where-Object IPAddress -eq '172.16.1.100'
    if ($assigned | Where-Object InterfaceIndex -ne $interfaceIndex) {
        throw '172.16.1.100 is already on another adapter. Check the VMware WAN-Net NIC.'
    }
    $otherWanAddress = $addresses | Where-Object {
        $_.InterfaceIndex -eq $interfaceIndex -and $_.IPAddress -ne '172.16.1.100' -and $_.IPAddress -notlike '169.254.*'
    }
    if ($otherWanAddress) {
        throw 'The selected adapter has another IPv4 address. Review its network settings before reusing it.'
    }
    if ($assigned) {
        Set-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -Dhcp Disabled
        if ($assigned.PrefixLength -ne 24) { $assigned | Set-NetIPAddress -PrefixLength 24 | Out-Null }
    } else {
        New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress '172.16.1.100' -PrefixLength 24 | Out-Null
    }
    Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ResetServerAddresses
    Write-Host "WAN-Net IPv4 172.16.1.100/24 configured on $WanAdapterAlias."
}

$guiSettings = Get-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\OpenVPN-GUI' -ErrorAction SilentlyContinue
$configDir = if ($guiSettings.config_dir) {
    [Environment]::ExpandEnvironmentVariables($guiSettings.config_dir)
} else {
    Join-Path $env:USERPROFILE 'OpenVPN\config'
}
New-Item -Path $configDir -ItemType Directory -Force | Out-Null
$existing = @(Get-ChildItem -LiteralPath $configDir -File -Filter 'client1.ovpn' -Recurse)
if ($existing.Count -gt 1) { throw 'More than one client1.ovpn is installed. Keep a single client1 profile.' }
$destination = if ($existing.Count -eq 1) { $existing[0].FullName } else { Join-Path $configDir 'client1.ovpn' }
if ($existing.Count -eq 0 -or (Get-FileHash -LiteralPath $profile.FullName).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    $staged = Join-Path (Split-Path -Parent $destination) ([IO.Path]::GetRandomFileName())
    try {
        [IO.File]::Copy($profile.FullName, $staged)
        if ($existing.Count -eq 1) {
            [IO.File]::Replace($staged, $destination, [NullString]::Value)
        } else {
            [IO.File]::Move($staged, $destination)
        }
    } finally {
        [IO.File]::Delete($staged)
    }
}

$sessionId = (Get-Process -Id $PID).SessionId
if (!(Get-Process -Name 'openvpn-gui' -ErrorAction SilentlyContinue | Where-Object SessionId -eq $sessionId)) {
    Start-Process -FilePath $guiPath
}
Write-Host "Profile installed at $destination"
Write-Host 'In OpenVPN GUI, select client1 and Connect. After connecting, open http://10.74.10.50.'
