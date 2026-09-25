$m = New-Object -ComObject HNetCfg.HNetShare
$wifiConn = $null
$ethConn = $null

foreach ($c in $m.EnumEveryConnection) {
    $p = $m.NetConnectionProps.Invoke($c)
    if ($p.Name -like "*Wi-Fi*") { $wifiConn = $c }
    if ($p.Name -like "*繧､繝ｼ繧ｵ繝阪ャ繝・" -or $p.Name -like "*Ethernet*") { $ethConn = $c }
}

if ($wifiConn -and $ethConn) {
    $wifiConfig = $m.INetSharingConfigurationForINetConnection.Invoke($wifiConn)
    $ethConfig = $m.INetSharingConfigurationForINetConnection.Invoke($ethConn)
    
    $wifiConfig.EnableSharing(0) # 0 = Public
    $ethConfig.EnableSharing(1) # 1 = Private
    [System.Windows.Forms.MessageBox]::Show("繧､繝ｳ繧ｿ繝ｼ繝阪ャ繝亥・譛峨ｒ譛牙柑蛹悶＠縺ｾ縺励◆・～n繝ｫ繝ｼ繧ｿ繝ｼ縺ｸ繧､繝ｳ繧ｿ繝ｼ繝阪ャ繝医・萓帷ｵｦ繧帝幕蟋九＠縺ｾ縺励◆縲・, "WorkManager 繝阪ャ繝亥・譛・, "OK", "Information")
} else {
    [System.Windows.Forms.MessageBox]::Show("Wi-Fi 縺ｾ縺溘・ 繧､繝ｼ繧ｵ繝阪ャ繝・縺瑚ｦ九▽縺九ｊ縺ｾ縺帙ｓ縺ｧ縺励◆縲・, "繧ｨ繝ｩ繝ｼ", "OK", "Error")
}
