@echo off

:loop
server.exe --headless
IF %ERRORLEVEL% == 42 (
    echo Restart requested...
    goto loop
)

echo Server exited with code %ERRORLEVEL%
pause
