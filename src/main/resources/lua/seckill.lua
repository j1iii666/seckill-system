-- 秒杀扣减脚本
-- KEYS[1] : 库存 key，例如 seckill:stock:1
-- KEYS[2] : 已抢用户集合 key，例如 seckill:users:1
-- KEYS[3] : 下单队列 key，例如 seckill:queue:1
-- ARGV[1] : 用户 id
-- 返回 1 = 抢到；-1 = 库存不足；-2 = 已经抢过
--
-- 关键设计：把「扣库存」和「写队列」放进同一个脚本。
-- 若在 Java 里先 EVAL 再 leftPush，两行之间进程崩溃就是「库存扣了、
-- 消息没入队、订单永远不会生成」的丢单窗口。Lua 整段原子执行，窗口消失。

local stock = tonumber(redis.call('GET', KEYS[1]))
if stock == nil or stock <= 0 then
    return -1
end

-- 同一个用户只能抢一次：先查集合里有没有他
local exists = redis.call('SISMEMBER', KEYS[2], ARGV[1])
if exists == 1 then
    return -2
end

redis.call('DECR', KEYS[1])            -- 扣库存
redis.call('SADD', KEYS[2], ARGV[1])   -- 记下这个人已抢
redis.call('LPUSH', KEYS[3], ARGV[1])  -- 入队（消费端用 rightPop，先进先出）
return 1
