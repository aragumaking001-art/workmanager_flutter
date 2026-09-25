' WorkManager 異常検知パトランプ監視デーモン（完全バックグラウンド・非表示起動）
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = currentDir

If fso.FileExists(currentDir & "\anomaly_lamp_daemon.exe") Then
    WshShell.Run """" & currentDir & "\anomaly_lamp_daemon.exe""", 0, False
Else
    WshShell.Run "pythonw.exe anomaly_lamp_daemon.py", 0, False
End If
