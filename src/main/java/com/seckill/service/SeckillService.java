package com.seckill.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class SeckillService {

    private final StringRedisTemplate redis;
    private final JdbcTemplate jdbc;
    private final DefaultRedisScript<Long> seckillScript;
    private final long goodsId;
    private final String stockKey;
    private final String queueKey;
    private final String processingKey;
    private final String usersKey;

    public SeckillService(StringRedisTemplate redis,
                          JdbcTemplate jdbc,
                          DefaultRedisScript<Long> seckillScript,
                          @Value("${seckill.goods-id}") long goodsId,
                          @Value("${seckill.stock-key}") String stockKey,
                          @Value("${seckill.queue-key}") String queueKey,
                          @Value("${seckill.processing-key}") String processingKey,
                          @Value("${seckill.users-key}") String usersKey) {
        this.redis = redis;
        this.jdbc = jdbc;
        this.seckillScript = seckillScript;
        this.goodsId = goodsId;
        this.stockKey = stockKey;
        this.queueKey = queueKey;
        this.processingKey = processingKey;
        this.usersKey = usersKey;
    }

    /** 预热：把 MySQL 里的真实库存写进 Redis。秒杀开始前必须调一次。 */
    public int warmUp() {
        Integer stock = jdbc.queryForObject(
                "SELECT stock FROM goods WHERE id = ?", Integer.class, goodsId);
        int s = stock == null ? 0 : stock;
        redis.opsForValue().set(stockKey, String.valueOf(s));
        return s;
    }

    /**
     * 核心：Lua 原子扣减（含用户去重 + 入队）。
     * 返回 1 = 抢到；-1 = 库存不足；-2 = 已经抢过。
     * 入队也在脚本里完成，Java 侧不再有「扣了库存却没入队」的中间态。
     */
    public String seckill(long userId) {
        Long result = redis.execute(seckillScript,
                List.of(stockKey, usersKey, queueKey), String.valueOf(userId));
        if (result == null) {
            return "系统繁忙";
        }
        if (result == -1) {
            return "库存不足";
        }
        if (result == -2) {
            return "你已经抢过了";
        }
        // 入队已在 Lua 脚本内完成，这里不再 leftPush
        return "抢购成功";
    }

    public String currentStock() {
        return redis.opsForValue().get(stockKey);
    }

    public long orderCount() {
        Long c = jdbc.queryForObject("SELECT COUNT(*) FROM `order` WHERE goods_id = ?", Long.class, goodsId);
        return c == null ? 0 : c;
    }

    public long queueSize() {
        Long size = redis.opsForList().size(queueKey);
        return size == null ? 0 : size;
    }

    /** 正在处理中（已取出、尚未确认写库）的消息数。 */
    public long processingSize() {
        Long size = redis.opsForList().size(processingKey);
        return size == null ? 0 : size;
    }

    /** 仅测试用：清空订单、库存、队列、已抢用户集合，方便反复跑并发验证。 */
    public void resetOrders() {
        jdbc.update("DELETE FROM `order`");
        redis.delete(List.of(stockKey, queueKey, processingKey, usersKey));
    }
}
