import os

lines = [
    "@echo off",
    'cd /d "%~dp0"',
    "title WorkManager 異常検知パトランプ自動監視デーモン",
    "echo ====================================================",
    "echo  WorkManager 異常検知パトランプ自動監視デーモン",
    "echo  (Tapo P105 制御サービス)",
    "echo ====================================================",
    "echo.",
    "",
    'if exist "..\\.venv\\Scripts\\python.exe" (',
    '    ..\\.venv\\Scripts\\python.exe anomaly_lamp_daemon.py',
    ") else (",
    "    python anomaly_lamp_daemon.py",
    ")",
    "",
    "pause",
    ""
]

content = "\r\n".join(lines)

with open("python_apps/run_anomaly_lamp.bat", "wb") as f:
    f.write(content.encode("cp932"))

print("SUCCESS: Written run_anomaly_lamp.bat in CP932 (Shift-JIS) with CRLF")
