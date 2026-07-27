$OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   📱 USB接続されているタブレットを精査しています..." -ForegroundColor Cyan
Write-Host "========================================================"

$shell = New-Object -ComObject Shell.Application
$mycomputer = $shell.Namespace(0x11)
$desktop = [System.Environment]::GetFolderPath("Desktop")
$destNamespace = $shell.Namespace($desktop)

$global:foundCount = 0

function Search-DownloadAndCopy($folder, $depth) {
    if ($depth -gt 3) { return } # 深追い防止
    foreach ($item in $folder.Items()) {
        if ($item.IsFolder) {
            # "Download" または "ダウンロード" ディレクトリ
            if ($item.Name -eq "Download" -or $item.Name -eq "ダウンロード") {
                Write-Host "  📂 ターゲットフォルダ [$($item.Name)] を発見！中を検索します..." -ForegroundColor White
                $dlFolder = $item.GetFolder
                if ($dlFolder) {
                    foreach ($file in $dlFolder.Items()) {
                        if ($file.Name -like "*work_logs*.csv" -or $file.Name -like "*.csv") {
                            Write-Host "  📦 検出＆回収中: $($file.Name) ➔ デスクトップへコピー" -ForegroundColor Cyan
                            try {
                                $destNamespace.CopyHere($file, 0x10)
                                $global:foundCount++
                            } catch {
                                Write-Host "  🚨 コピー中に警告: $_" -ForegroundColor Red
                            }
                        }
                    }
                }
            } else {
                # デバイスの内部ストレージ等をたどる
                $subFolder = $item.GetFolder
                if ($subFolder) {
                    Search-DownloadAndCopy $subFolder ($depth + 1)
                }
            }
        }
    }
}

Write-Host "`n🔍 【接続中のデバイス・ドライブ一覧の確認】" -ForegroundColor Yellow
$deviceNames = @()
foreach ($dev in $mycomputer.Items()) {
    if ($dev.IsFolder -and $dev.Name -notlike "* (C:)*" -and $dev.Name -notlike "* (D:)*") {
        $deviceNames += $dev.Name
        Write-Host " 💻 見つかったデバイス/ストレージ: [$($dev.Name)] ➔ スキャン開始！" -ForegroundColor Green
        $devFolder = $dev.GetFolder
        if ($devFolder) {
            Search-DownloadAndCopy $devFolder 0
        }
    }
}

if ($deviceNames.Count -eq 0) {
    Write-Host " ⚠️ タブレットなどの外部デバイスが認識されておりません！" -ForegroundColor Red
    Write-Host "    [ヒント] エクスプローラー(PC画面)でタブレットのアイコンが表示されていますか？" -ForegroundColor White
}

Write-Host "========================================================" -ForegroundColor Cyan
if ($global:foundCount -gt 0) {
    Write-Host "🎉 【大大成功】: 合計 $global:foundCount 件の CSVファイル をパソコンのデスクトップに引き上げました！" -ForegroundColor Green
} else {
    Write-Host "⚠️ 【結果レポート】: 接続機器の中に新しい CSV ファイルは見つかりませんでした。" -ForegroundColor Yellow
    Write-Host "   📌 チェック項目:"
    Write-Host "    ① タブレットのアプリ側で「ダウンロードボタン」をお押しになりましたか？"
    Write-Host "    ② USBケーブルを繋いだ時、タブレットの画面で『ファイル転送(MTP)』等を選びましたか？"
}
Write-Host "========================================================" -ForegroundColor Cyan
