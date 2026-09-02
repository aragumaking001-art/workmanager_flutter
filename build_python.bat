@echo off
echo Building python apps...
pyinstaller --onefile --noconsole python_apps/dashboard_workplace.py
pyinstaller --onefile --noconsole python_apps/work_app.py
echo Build finished! The executable files can be found in the dist/ folder.
