@echo off
chcp 65001 > nul
title 現場ルーター ネット共有ツール (ICS)

:: 管理者権限チェック＆自動昇格
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 管理者権限で起動し直しています...
    powershell -Command "Start-Process cmd -ArgumentList '/c `\"%~f0`\"' -Verb RunAs"
    exit /b
)

echo ====================================================
echo  Wi-Fiのインターネットを現場ルーター(WAN)に共有中...
echo ====================================================

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$m = New-Object -ComObject HNetCfg.HNetShare; " ^
    "$wifi = $null; $eth = $null; " ^
    "foreach ($c in $m.EnumEveryConnection) { " ^
    "    $p = $m.NetConnectionProps.Invoke($c); " ^
    "    if ($p.Name -like '*Wi-Fi*') { $wifi = $c } " ^
    "    if ($p.Name -like '*イーサネット*' -or $p.Name -like '*Ethernet*') { $eth = $c } " ^
    "} " ^
    "if ($wifi -and $eth) { " ^
    "    $w = $m.INetSharingConfigurationForINetConnection.Invoke($wifi); " ^
    "    $e = $m.INetSharingConfigurationForINetConnection.Invoke($eth); " ^
    "    $w.EnableSharing(0); " ^
    "    $e.EnableSharing(1); " ^
    "    Write-Host '【成功】インターネット共有をONにしました！' -ForegroundColor Green; " ^
    "    Write-Host '現場ルーターのWANにインターネットが流れ始めました。' -ForegroundColor Cyan; " ^
    "} else { " ^
    "    Write-Host '【エラー】Wi-Fiまたはイーサネットが見つかりませんでした。' -ForegroundColor Red; " ^
    "}"

echo.
echo 何かキーを押すとこの画面を閉じます...
pause > nul
