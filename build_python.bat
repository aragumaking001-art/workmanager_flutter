@echo off
setlocal
echo Building python apps...
set PYINSTALLER_CMD=pyinstaller
if exist "%~dp0.venv\Scripts\pyinstaller.exe" (
    set "PYINSTALLER_CMD=%~dp0.venv\Scripts\pyinstaller.exe"
)

cd /d "%~dp0python_apps"
"%PYINSTALLER_CMD%" dashboard_workplace.spec
"%PYINSTALLER_CMD%" work_app.spec
"%PYINSTALLER_CMD%" ScheduleImporter.spec
cd /d "%~dp0"
echo Build finished! The executable files can be found in the python_apps/dist/ folder.
endlocal

