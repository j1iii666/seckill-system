@echo off
chcp 65001 >nul
title seckill - start Redis (127.0.0.1:6379)

rem Redis 根目录：优先用环境变量 REDIS_HOME，否则自动探测常见安装位置
if not defined REDIS_HOME (
    if exist "C:\Redis\bin\redis-server.exe" set "REDIS_HOME=C:\Redis"
    if exist "D:\Redis\bin\redis-server.exe" set "REDIS_HOME=D:\Redis"
    if exist "%LOCALAPPDATA%\Redis\bin\redis-server.exe" set "REDIS_HOME=%LOCALAPPDATA%\Redis"
)
if not defined REDIS_HOME (
    echo [FAIL] 没找到 Redis。请设置环境变量 REDIS_HOME 指向 Redis 根目录
    echo         ^(该目录下应该有 bin\redis-server.exe 和 redis.conf^)
    echo.
    pause
    exit /b 1
)

echo ============================================
echo  Starting Redis from %REDIS_HOME% ...
echo  Close this window or press Ctrl+C to stop.
echo ============================================
echo.

cd /d "%REDIS_HOME%"
start "" /min "%REDIS_HOME%\bin\redis-server.exe" "%REDIS_HOME%\redis.conf"
timeout /t 2 >nul
echo Ping:
"%REDIS_HOME%\bin\redis-cli.exe" -h 127.0.0.1 -p 6379 ping
echo.
pause
