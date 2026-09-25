# Enable ICS on Wi-Fi sharing to Ethernet
import subprocess
import time

ps_script = """
$m = New-Object -ComObject HNetCfg.HNetShare
$wifiConn = $null
$ethConn = $null

foreach ($c in $m.EnumEveryConnection) {
    $p = $m.NetConnectionProps.Invoke($c)
    if ($p.Name -like "*Wi-Fi*") { $wifiConn = $c }
    if ($p.Name -like "*イーサネット*" -or $p.Name -like "*Ethernet*") { $ethConn = $c }
}

Write-Host "Wi-Fi Conn: " ($wifiConn -ne $null)
Write-Host "Ethernet Conn: " ($ethConn -ne $null)

if ($wifiConn -and $ethConn) {
    # Configure Wi-Fi as public sharing
    $wifiConfig = $m.INetSharingConfigurationForINetConnection.Invoke($wifiConn)
    $ethConfig = $m.INetSharingConfigurationForINetConnection.Invoke($ethConn)
    
    # 0 = public (shared), 1 = private (home)
    $wifiConfig.EnableSharing(0)
    $ethConfig.EnableSharing(1)
    Write-Host "ICS successfully enabled!"
} else {
    Write-Host "Connections not found"
}
"""

with open("scratch/enable_ics.ps1", "w", encoding="utf-8") as f:
    f.write(ps_script)

print("Created scratch/enable_ics.ps1")
