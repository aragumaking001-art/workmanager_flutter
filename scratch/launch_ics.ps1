# Enable ICS via PowerShell with UAC
$code = @'
$m = New-Object -ComObject HNetCfg.HNetShare
$wifiConn = $null
$ethConn = $null

foreach ($c in $m.EnumEveryConnection) {
    $p = $m.NetConnectionProps.Invoke($c)
    if ($p.Name -like "*Wi-Fi*") { $wifiConn = $c }
    if ($p.Name -like "*イーサネット*" -or $p.Name -like "*Ethernet*") { $ethConn = $c }
}

if ($wifiConn -and $ethConn) {
    $wifiConfig = $m.INetSharingConfigurationForINetConnection.Invoke($wifiConn)
    $ethConfig = $m.INetSharingConfigurationForINetConnection.Invoke($ethConn)
    
    $wifiConfig.EnableSharing(0) # 0 = Public
    $ethConfig.EnableSharing(1) # 1 = Private
    [System.Windows.Forms.MessageBox]::Show("インターネット共有を有効化しました！`nルーターへインターネットの供給を開始しました。", "WorkManager ネット共有", "OK", "Information")
} else {
    [System.Windows.Forms.MessageBox]::Show("Wi-Fi または イーサネット が見つかりませんでした。", "エラー", "OK", "Error")
}
'@

Add-Type -AssemblyName System.Windows.Forms
$scriptPath = "$PSScriptRoot\ics_runas.ps1"
Set-Content -Path $scriptPath -Value $code -Encoding UTF8

Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
