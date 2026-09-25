@echo off
cd /d "%~dp0"
title WorkManager Anomaly Lamp Monitor

if exist "anomaly_lamp_daemon.exe" (
    anomaly_lamp_daemon.exe %*
) else if exist "..\.venv\Scripts\python.exe" (
    ..\.venv\Scripts\python.exe anomaly_lamp_daemon.py %*
) else (
    python anomaly_lamp_daemon.py %*
)

if %errorlevel% neq 0 (
    echo.
    echo Process exited with error code %errorlevel%.
    pause
)
