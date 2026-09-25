# Self-elevate to Administrator if not already
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  WorkManager 現場ルーター ネット共有ツール" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ネットワークアダプターを検索中..." -ForegroundColor Gray

try {
    $m = New-Object -ComObject HNetCfg.HNetShare
    $wifi = $null
    $eth = $null
    
    foreach ($c in $m.EnumEveryConnection) {
        $p = $m.NetConnectionProps.Invoke($c)
        $n = $p.Name
        Write-Host "  - 検出: $n" -ForegroundColor DarkGray
        
        # Wi-Fi の判定
        if ($n -like "*Wi-Fi*") {
            $wifi = $c
        }
        # 有線LAN（イーサネット）の判定: Wi-FiでもBluetoothでもない接続
        elseif ($n -notlike "*Bluetooth*" -and $n -notlike "*Wi-Fi*" -and $n -notlike "*仮想*" -and $n -notlike "*Virtual*") {
            $eth = $c
        }
    }
    
    if (-not $wifi) {
        Write-Host ""
        Write-Host "[エラー] Wi-Fi接続が見つかりませんでした。" -ForegroundColor Red
        Write-Host "スマホのテザリングにPCがWi-Fi接続されているか確認してください。" -ForegroundColor Yellow
        Read-Host "Enterキーを押して終了してください..."
        exit 1
    }
    
    if (-not $eth) {
        Write-Host ""
        Write-Host "[エラー] 有線LANアダプターが見つかりませんでした。" -ForegroundColor Red
        Read-Host "Enterキーを押して終了してください..."
        exit 1
    }
    
    Write-Host ""
    Write-Host "Wi-Fi (インターネット側) と 有線LAN (WAN側) を特定しました！" -ForegroundColor Yellow
    Write-Host "インターネット共有を設定中..." -ForegroundColor Gray
    
    $w = $m.INetSharingConfigurationForINetConnection.Invoke($wifi)
    $e = $m.INetSharingConfigurationForINetConnection.Invoke($eth)
    
    $w.EnableSharing(0) # 0 = Public (共有元)
    $e.EnableSharing(1) # 1 = Private (共有先)
    
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host " 【大成功】インターネット共有をONにしました！" -ForegroundColor Green
    Write-Host " 現場ルーターのWANにインターネットが流れ始めました！" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "スマホのTapoアプリに戻り、「再試行」を押してください！" -ForegroundColor Cyan
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "[エラーが発生しました]" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}

Read-Host "Enterキーを押すと画面を閉じます..."
