# Self-elevate to Administrator if not already
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  現場ネットワーク復旧ツール（共有OFF ＆ 正常復元）" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # 1. ICS共有を無効化
    Write-Host "1. インターネット共有をOFFにしています..." -ForegroundColor Gray
    $m = New-Object -ComObject HNetCfg.HNetShare
    foreach ($c in $m.EnumEveryConnection) {
        $cfg = $m.INetSharingConfigurationForINetConnection.Invoke($c)
        if ($cfg.SharingEnabled) {
            $cfg.DisableSharing()
        }
    }
    Write-Host "   -> 共有の解除完了" -ForegroundColor Green
    
    # 2. 有線LANアダプターのIPを元の現場設定 (192.168.10.152) に復元
    Write-Host "2. 有線LANアダプターのIPを元の現場LAN (192.168.10.152) に復元中..." -ForegroundColor Gray
    
    # イーサネットアダプターの特定
    $ethAdapter = Get-NetAdapter | Where-Object { $_.Name -notlike "*Wi-Fi*" -and $_.Name -notlike "*Bluetooth*" -and $_.Status -ne "Disabled" } | Select-Object -First 1
    
    if ($ethAdapter) {
        $adapterName = $ethAdapter.Name
        Write-Host "   対象アダプター: $adapterName" -ForegroundColor DarkGray
        
        # 既存の 192.168.137.1 などのIPを削除
        Get-NetIPAddress -InterfaceIndex $ethAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        
        # 元の固定IP (192.168.10.152 / 24, Gateway: 192.168.10.1) を再設定
        New-NetIPAddress -InterfaceIndex $ethAdapter.InterfaceIndex -IPAddress 192.168.10.152 -PrefixLength 24 -DefaultGateway 192.168.10.1 -ErrorAction SilentlyContinue
        
        # DNSサーバー設定（もしあれば）
        Set-DnsClientServerAddress -InterfaceIndex $ethAdapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        
        Write-Host "   -> IPアドレスを 192.168.10.152 に復元しました！" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host " 【復旧完了】現場ネットワークの設定が完全に元に戻りました！" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[エラー] $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "Enterキーを押すと画面を閉じます..."
