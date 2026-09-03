@echo off
echo Building python apps...
cd python_apps
pyinstaller dashboard_workplace.spec
pyinstaller work_app.spec
cd ..
echo Build finished! The executable files can be found in the python_apps/dist/ folder.
