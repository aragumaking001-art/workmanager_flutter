@echo off
chcp 65001 > nul
title 【タブレットCSV】一撃スピードお取り寄せツール
echo ========================================================
echo   📱 USB接続中のタブレットから最新CSVを回収中...
echo ========================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = [System.IO.File]::ReadAllText('%~f0', [System.Text.Encoding]::UTF8); $idx = $script.IndexOf('###_POWERSHELL_START_###'); Invoke-Expression ($script.Substring($idx));"

echo.
echo ========================================================
echo   ✨ 処理完了！(この窓は 4 秒後に自動で静かに閉じます)
echo ========================================================
timeout /t 4 > nul
exit /b

###_POWERSHELL_START_###
$shell = New-Object -ComObject Shell.Application
$mycomputer = $shell.Namespace(0x11)
$desktop = [System.Environment]::GetFolderPath("Desktop")
$destNamespace = $shell.Namespace($desktop)

$global:foundCount = 0

# タブレット/ポータブルデバイスの深いフォルダツリーを瞬速で自動捜索！
function Search-DownloadAndCopy($folder, $depth) {
    if ($depth -gt 3) { return } # 深追いすぎの自動防止
    foreach ($item in $folder.Items()) {
        if ($item.IsFolder) {
            # "Download" 又は "ダウンロード" ディレクトリを感知！
            if ($item.Name -eq "Download" -or $item.Name -eq "ダウンロード") {
                $dlFolder = $item.GetFolder
                if ($dlFolder) {
                    foreach ($file in $dlFolder.Items()) {
                        if ($file.Name -like "work_logs_*.csv" -or $file.Name -like "*work_logs*.csv") {
                            Write-Host "  📦 発見＆お取り寄せ中: $($file.Name)" -ForegroundColor Cyan
                            # デスクトップに軽快コピー (0x10 = Yes to All 上書き許容)
                            $destNamespace.CopyHere($file, 0x10)
                            $global:foundCount++
                        }
                    }
                }
            } else {
                # 内部ストレージや SDカード領域へ潜る
                $subFolder = $item.GetFolder
                if ($subFolder) {
                    Search-DownloadAndCopy $subFolder ($depth + 1)
                }
            }
        }
    }
}

Write-Host "🔍 探索中: パソコンに接続されたタブレット(またはUSBフラッシュメモリ等)の Download フォルダをお尋ね中..." -ForegroundColor White

foreach ($dev in $mycomputer.Items()) {
    # Cドライブ等以外（タブレット等のポータブルデバイス）をすべて自動選出
    if ($dev.IsFolder -and $dev.Name -notlike "* (C:)*" -and $dev.Name -notlike "* (D:)*") {
        $devFolder = $dev.GetFolder
        if ($devFolder) {
            Search-DownloadAndCopy $devFolder 0
        }
    }
    # 万一USBストレージ（E〜Zドライブ）で認識された場合も同時にケア
    if ($dev.Name -like "* (*:)*" -and $dev.Name -notlike "* (C:)*" -and $dev.Name -notlike "* (D:)*") {
        $devFolder = $dev.GetFolder
        if ($devFolder) {
            Search-DownloadAndCopy $devFolder 0
        }
    }
}

if ($global:foundCount -gt 0) {
    Write-Host ""
    Write-Host "🎉 大成功！！ 合計 $global:foundCount 件の CSVファイル をお使いの『 デスクトップ 』にお届けしました！" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ 【結果】タブレット内部に [ work_logs_*.csv ] が見あたりませんでした。" -ForegroundColor Yellow
    Write-Host "  💡 確認ポイント:"
    Write-Host "   ・タブレット側のアプリの右上ボタンで、事前に保存をタッチしましたか？"
    Write-Host "   ・USBケーブルで繋いだ後、タブレット画面に『ファイル転送 (MTP) 』などの許可通知が出ている場合は『許可(またはファイル転送)』を選択してください！"
}
