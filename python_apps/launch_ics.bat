@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0enable_ics.ps1"
