@echo off
chcp 65001 >nul
title seckill - combo (连击抢购)
rem 双击运行 = 连击 99 下
rem 想改次数：在命令行里跑  combo.bat -Count 100
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0combo.ps1" %*
echo.
pause
