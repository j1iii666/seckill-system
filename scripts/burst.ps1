# 模拟"100 个人同时点抢购"：并发发出 100 个不同用户的抢购请求
# 用法（需要 PowerShell 7）：pwsh -File scripts\burst.ps1
#   想改连击次数：pwsh -File scripts\burst.ps1 -Count 500
# 提示：日常演示用 combo.bat（Windows PowerShell 5.1 也能跑）；这个脚本主要用来打并发。
param([int]$Count = 100)

Write-Output "向 8081 并发发出 $Count 个抢购请求..."

1..$Count | ForEach-Object -Parallel {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:8081/api/seckill?userId=$_" -Method Get -TimeoutSec 10 | Out-Null
    } catch {
        # 单个失败忽略
    }
} -ThrottleLimit 50

Write-Output "发完了。去看页面的库存和订单数（每秒自动刷新）。"
