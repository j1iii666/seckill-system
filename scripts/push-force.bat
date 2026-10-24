@echo off
title seckill - FORCE push (rewrite author)
cd /d "%~dp0.."

echo ============================================
echo  FORCE PUSH  -  this REPLACES the commit on GitHub
echo.
echo  Use it only after the local commit author was rewritten
echo  (email changed to the GitHub noreply address).
echo.
echo  Remote: https://github.com/j1iii666/seckill-system
echo ============================================
echo.
echo Current commit:
git log -1 --format="  author: %%an ^<%%ae^>"
echo.
set /p OK=Type Y to force push, anything else to cancel: 
if /i not "%OK%"=="Y" goto CANCEL
echo.
echo Attempt 1/3: pushing with --force-with-lease...
git push --force-with-lease origin main
set RC=%ERRORLEVEL%
if "%RC%"=="0" goto OKMSG

echo.
echo Attempt 1 failed. Retrying with OpenSSL TLS backend...
git -c http.sslBackend=openssl push --force-with-lease origin main
set RC=%ERRORLEVEL%
if "%RC%"=="0" goto OKMSG
goto FAIL

:OKMSG
echo.
echo ============================================
echo  [OK] Force push succeeded
echo  Check: https://github.com/j1iii666/seckill-system/commits/main
echo ============================================
goto END

:CANCEL
echo.
echo Cancelled, nothing was pushed.
goto END

:FAIL
echo.
echo ============================================
echo  [FAIL] Force push failed, exit code %RC%
echo  Copy the full output above and report it.
echo ============================================

:END
echo.
pause
