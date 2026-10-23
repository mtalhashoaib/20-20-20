@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*EyeBreak.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\EyeBreak.vbs" 2>nul
rmdir /S /Q "%APPDATA%\EyeBreak" 2>nul
echo 20-20-20 reminder removed.
pause
