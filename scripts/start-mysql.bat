@echo off
title seckill - start MySQL 84

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================
echo  Starting MySQL84 service ...
echo ============================================
echo.
net start MySQL84
set RC=%ERRORLEVEL%
echo.
if "%RC%"=="0" goto OK
if "%RC%"=="2" goto ALREADY
goto FAIL

:OK
echo [OK] MySQL84 started.
goto END

:ALREADY
echo [OK] MySQL84 was already running.
goto END

:FAIL
echo [FAIL] could not start MySQL84, error code %RC%
echo Check the mysql-error.log under your MySQL data directory for the reason.

:END
echo.
echo Status:
sc query MySQL84 | findstr /C:"STATE"
echo.
pause
