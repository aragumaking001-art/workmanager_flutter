@echo off
chcp 65001 > nul
title 現場ルーター ネット共有解除ツール

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c `\"%~f0`\"' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$m = New-Object -ComObject HNetCfg.HNetShare; " ^
    "foreach ($c in $m.EnumEveryConnection) { " ^
    "    $cfg = $m.INetSharingConfigurationForINetConnection.Invoke($c); " ^
    "    if ($cfg.SharingEnabled) { $cfg.DisableSharing() } " ^
    "} " ^
    "Write-Host '【完了】インターネット共有をOFF（元の閉域網）に戻しました！' -ForegroundColor Green;"

echo.
echo 何かキーを押すとこの画面を閉じます...
pause > nul
