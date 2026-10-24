@echo off
title seckill - push to GitHub
cd /d "%~dp0.."

echo ============================================
echo  Pushing to https://github.com/j1iii666/seckill-system
echo ============================================
echo.
git remote -v
echo.
echo Attempt 1/2: pushing... a GitHub login window may pop up, approve it.
git push -u origin main
set RC=%ERRORLEVEL%
if "%RC%"=="0" goto OK

echo.
echo Attempt 1 failed. Retrying with OpenSSL TLS backend...
git -c http.sslBackend=openssl push -u origin main
set RC=%ERRORLEVEL%
if "%RC%"=="0" goto OK
goto FAIL

:OK
echo.
echo ============================================
echo  [OK] Push succeeded
echo  Open it: https://github.com/j1iii666/seckill-system
echo ============================================
goto END

:FAIL
echo.
echo ============================================
echo  [FAIL] Push failed, exit code %RC%
echo.
echo  What to do:
echo   1) Sign-in issue: a login window should pop up. If it never does,
echo      create a Personal Access Token at github.com/settings/tokens,
echo      then when git asks for a password, paste the token instead.
echo   2) Repo already has a README or LICENSE: run
echo        git pull --rebase origin main
echo      then run this script again.
echo   3) Anything else: copy the full output above and report it.
echo ============================================

:END
echo.
pause
