@echo off
rem Stop any older running copy first so updates take effect
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*EyeBreak.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
set "DEST=%APPDATA%\EyeBreak"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
mkdir "%DEST%" 2>nul
copy /Y "%~dp0EyeBreak.ps1" "%DEST%\EyeBreak.ps1" >nul
echo CreateObject("Wscript.Shell").Run "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""%DEST%\EyeBreak.ps1""", 0 > "%STARTUP%\EyeBreak.vbs"
wscript "%STARTUP%\EyeBreak.vbs"
echo.
echo Installed. A small countdown appears at the bottom-right of your screen
echo and the app will start automatically every time you log in.
pause
