@echo off&&cd /D %~dp0
cd ..\
:: Create a shortcut on the desktop ::
echo.
echo [92m::::::::: Create a shortcut on the desktop ::::::::::[0m
powershell -command "$date=Get-Date -Format 'yyyy-MM-dd HH-mm'; $s=(New-Object -ComObject WScript.Shell).CreateShortcut('%USERPROFILE%\Desktop\ComfyUI-EZi ' + $date + '.lnk'); $s.TargetPath='%cd%\run_nvidia_gpu.bat'; $s.WorkingDirectory='%cd%\'; $s.IconLocation='%cd%\ComfyUI\ComfyUI-Easy-Install.ico'; $s.Save();"
