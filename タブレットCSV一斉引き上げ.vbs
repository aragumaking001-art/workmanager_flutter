Option Explicit

Dim objShell, objMyComputer, objDestFolder, objDev, objDevFolder, foundCount

Set objShell = CreateObject("Shell.Application")
' 17 (0x11) = マイコンピュータ / PC
Set objMyComputer = objShell.Namespace(17)
' 16 (0x10) = ユーザーのデスクトップ
Set objDestFolder = objShell.Namespace(16)

foundCount = 0

Sub SearchDownloadFolder(fldr, depth)
    If depth > 4 Then Exit Sub ' 深すぎるスキャンを避ける安全設計
    Dim items, item, subFldr, fileItem
    On Error Resume Next
    Set items = fldr.Items()
    For Each item In items
        If item.IsFolder Then
            ' Download 又は ダウンロード フォルダに到達！
            If UCase(item.Name) = "DOWNLOAD" Or item.Name = "ダウンロード" Then
                Set subFldr = item.GetFolder
                If Not subFldr Is Nothing Then
                    For Each fileItem In subFldr.Items()
                        ' work_logs_ や .csv で終わるファイルを回収！
                        If InStr(LCase(fileItem.Name), ".csv") > 0 And InStr(LCase(fileItem.Name), "work_logs") > 0 Then
                            ' 16(0x10) = 上書き問い合わせを自動 Yes にして静かにスマートコピー
                            objDestFolder.CopyHere fileItem, 16
                            foundCount = foundCount + 1
                        End If
                    Next
                End If
            Else
                ' 内部共有ストレージ等のツリーへも潜行
                Set subFldr = item.GetFolder
                If Not subFldr Is Nothing Then
                    SearchDownloadFolder subFldr, depth + 1
                End If
            End If
        End If
    Next
    On Error GoTo 0
End Sub

' PCに接続されている各種デバイス・タブレットを全力探索
On Error Resume Next
For Each objDev In objMyComputer.Items()
    ' Cドライブ等既存のパソコン内ハードディスク以外(外部タブレットやUSB)を指定
    If objDev.IsFolder And InStr(objDev.Name, "(C:)") = 0 And InStr(objDev.Name, "(D:)") = 0 Then
        Set objDevFolder = objDev.GetFolder
        If Not objDevFolder Is Nothing Then
            SearchDownloadFolder objDevFolder, 0
        End If
    End If
    ' もし USB ストレージ (E: や F: など) としても同時検知された場合も逃さず検索
    If InStr(objDev.Name, "(:)") > 0 And InStr(objDev.Name, "(C:)") = 0 And InStr(objDev.Name, "(D:)") = 0 Then
        Set objDevFolder = objDev.GetFolder
        If Not objDevFolder Is Nothing Then
            SearchDownloadFolder objDevFolder, 0
        End If
    End If
Next
On Error GoTo 0

' 上品で確かなポップアップメッセージで結果通知！
If foundCount > 0 Then
    MsgBox "🎉 【 回収大成功！！ 】" & vbCrLf & vbCrLf & "接続されたタブレットから 合計 " & foundCount & " 件の CSVファイル(実績) を、このPCの「デスクトップ」に移動しました！" & vbCrLf & vbCrLf & "デスクトップ画面の work_logs_*.csv をご覧ください！", 64, "タブレットCSV お取り寄せ結果"
Else
    MsgBox "⚠️ 接続されているタブレット(Downloadフォルダ)に、新しい [ work_logs_*.csv ] が見つけられませんでした。" & vbCrLf & vbCrLf & "💡 解決の必須ヒント:" & vbCrLf & "  ① タブレットとパソコンがUSBで確実に繋がっているかご確認ください。" & vbCrLf & "  ②【超重要】USBで繋いだ際、タブレット側の画面に『ファイル転送(MTP)』等の確認が出ている場合は、許可(転送)を選択してください！（※「充電のみ」だとPCから中身が見えません！）" & vbCrLf & "  ③ まずタブレット側のアプリの右上ダウンロードボタンを押した後に実行してください。", 48, "お知らせ・見当たらなかった場合"
End If
