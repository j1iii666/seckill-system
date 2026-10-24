@echo off
chcp 65001 >nul
title seckill - init database

rem 本脚本所在的 scripts 目录（不写死绝对路径）
set "HERE=%~dp0"

rem ---- 找 mysql.exe：优先 PATH，其次常见安装目录，也可用环境变量 MYSQL_EXE 指定 ----
set "MYSQL_EXE=mysql"
where mysql >nul 2>nul
if not errorlevel 1 goto HAVE_MYSQL

set "MYSQL_EXE="
for %%P in (
    "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
    "D:\MySQL\MySQL Server 8.4\bin\mysql.exe"
    "D:\MySQL\MySQL Server 8.0\bin\mysql.exe"
) do if exist %%P if not defined MYSQL_EXE set "MYSQL_EXE=%%~P"

:HAVE_MYSQL
if not defined MYSQL_EXE (
    echo [FAIL] 没找到 mysql.exe。请把 MySQL 的 bin 目录加进 PATH，
    echo        或者设置环境变量 MYSQL_EXE 指向 mysql.exe 的完整路径。
    echo.
    pause
    exit /b 1
)

echo ============================================
echo  第 1 步：建库建表（会要你把 MySQL root 密码输两次）
echo ============================================
echo.
"%MYSQL_EXE%" --protocol=TCP -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 --execute="source %HERE:\=/%init-db.sql"

echo.
echo ============================================
echo  第 2 步：给应用用的数据库账号设密码
echo  这个密码必须和 src\main\resources\application-local.yml 里写的一致
echo ============================================
echo.
set "DBPASS="
set /p DBPASS=请输入要给 seckill 用户设置的密码（直接回车 = 跳过，保持原密码）: 
if not defined DBPASS goto SKIP_USER
"%MYSQL_EXE%" --protocol=TCP -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 --execute="CREATE USER IF NOT EXISTS 'seckill'@'%%' IDENTIFIED BY '%DBPASS%'; ALTER USER 'seckill'@'%%' IDENTIFIED BY '%DBPASS%'; GRANT ALL PRIVILEGES ON seckill.* TO 'seckill'@'%%'; FLUSH PRIVILEGES;"
if errorlevel 1 (
    echo [FAIL] 设置账号密码失败，把上面的报错原样贴出来排查。
) else (
    echo [OK] 应用账号 seckill 的密码已设置。
)
:SKIP_USER

echo.
echo 上面若出现 INIT_OK，说明建库建表成功。
pause
