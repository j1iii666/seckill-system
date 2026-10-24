# 连击脚本：连续抢购 N 次（每次换一个随机用户）
#
# 用法（双击 scripts\combo.bat 也行，默认连击 99 下）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\combo.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\combo.ps1 -Count 100
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\combo.ps1 -Count 20 -DelayMs 300
#
# 参数：
#   -Count    连击次数，默认 99
#   -DelayMs  每次之间停顿毫秒数，默认 0（不停）
#   -BaseUrl  服务地址，默认 http://127.0.0.1:8081
#
# 注意：本文件必须存成「UTF-8 带 BOM」，否则 Windows PowerShell 5.1 会按 GBK 读，
# 中文直接变乱码、甚至报语法错误。

param(
    [int]$Count = 99,
    [int]$DelayMs = 0,
    [string]$BaseUrl = "http://127.0.0.1:8081"
)

# 统一按 UTF-8 字节解码再转 JSON：
# Windows PowerShell 5.1 的 Invoke-RestMethod 会把无 charset 的 JSON 当 Latin-1 解，
# 中文会变成「æ¢è­æå」这种乱码，后续字符串比较全部失效。
function Get-ApiJson {
    param([string]$Url, [string]$Method = "Post")
    $resp = Invoke-WebRequest -Uri $Url -Method $Method -TimeoutSec 10 -UseBasicParsing
    $text = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    return $text | ConvertFrom-Json
}

# 先探活，避免对着没启动的服务刷一堆连接失败
try {
    $null = Get-ApiJson -Url "$BaseUrl/api/status" -Method Get
} catch {
    Write-Host "连不上 $BaseUrl —— 先把应用启动起来（java -jar target\seckill-1.0.0.jar）" -ForegroundColor Red
    exit 1
}

$ok = 0; $noStock = 0; $dup = 0; $fail = 0
$begin = Get-Date

Write-Host ("开始连击 {0} 下 -> {1}" -f $Count, $BaseUrl) -ForegroundColor Cyan
Write-Host ("-" * 56)

for ($i = 1; $i -le $Count; $i++) {
    $uid = Get-Random -Minimum 100000 -Maximum 999999999
    try {
        $r = Get-ApiJson -Url "$BaseUrl/api/seckill?userId=$uid" -Method Post
        if ($r.code -eq 0) {
            $ok++
            $label = "抢购成功"
            $color = "Green"
        } elseif ($r.msg -like "*库存不足*") {
            $noStock++
            $label = "库存不足"
            $color = "Yellow"
        } elseif ($r.msg -like "*抢过了*") {
            $dup++
            $label = "重复抢购"
            $color = "DarkGray"
        } else {
            $fail++
            $label = "其它失败"
            $color = "Red"
        }
        Write-Host ("[{0,3}/{1}] {2}  用户{3}  累计成功 {4}" -f $i, $Count, $label, $uid, $ok) -ForegroundColor $color
    } catch {
        $fail++
        Write-Host ("[{0,3}/{1}] 请求异常：{2}" -f $i, $Count, $_.Exception.Message) -ForegroundColor Red
    }
    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
}

$cost = ((Get-Date) - $begin).TotalMilliseconds

Write-Host ("-" * 56)
Write-Host ("连击结束，耗时 {0:N0} ms" -f $cost) -ForegroundColor Cyan
Write-Host ("  抢购成功 : {0}" -f $ok)      -ForegroundColor Green
Write-Host ("  库存不足 : {0}" -f $noStock) -ForegroundColor Yellow
Write-Host ("  重复抢购 : {0}" -f $dup)     -ForegroundColor DarkGray
Write-Host ("  请求失败 : {0}" -f $fail)    -ForegroundColor Red

try {
    $s = Get-ApiJson -Url "$BaseUrl/api/status" -Method Get
    Write-Host ""
    Write-Host ("服务端现状：库存 {0} 件 / 订单 {1} 单 / 队列积压 {2}" -f $s.stock, $s.orders, $s.queue) -ForegroundColor White
    if ([int]$s.stock -le 0) {
        Write-Host "库存已是 0：页面会在 1 秒内自动弹出「已售罄」。" -ForegroundColor Magenta
    }
} catch { }
