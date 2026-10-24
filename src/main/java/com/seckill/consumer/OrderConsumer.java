package com.seckill.consumer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * 台账工人：从队列另一头一条一条取消息，取到就写订单，写不动就等。
 * 这就是"异步下单"的消费者。
 *
 * 可靠性要点：取消息用 RPOPLPUSH（阻塞版），先把消息搬到 processing 列表
 * 再干活，写库成功才从 processing 里删掉。这样"取出来但没写进库"的消息
 * 留在 processing 里不会被丢，可以人工/定时任务补偿。
 */
@Component
public class OrderConsumer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(OrderConsumer.class);

    private final StringRedisTemplate redis;
    private final JdbcTemplate jdbc;
    private final String queueKey;
    private final String processingKey;
    private final long goodsId;

    public OrderConsumer(StringRedisTemplate redis,
                         JdbcTemplate jdbc,
                         @Value("${seckill.queue-key}") String queueKey,
                         @Value("${seckill.processing-key}") String processingKey,
                         @Value("${seckill.goods-id}") long goodsId) {
        this.redis = redis;
        this.jdbc = jdbc;
        this.queueKey = queueKey;
        this.processingKey = processingKey;
        this.goodsId = goodsId;
    }

    @Override
    public void run(String... args) {
        // 后台守护线程，应用退出时自动结束
        Thread worker = new Thread(this::consumeLoop, "order-consumer");
        worker.setDaemon(true);
        worker.start();
    }

    private void consumeLoop() {
        while (true) {
            try {
                // 从右端取一条并原子地搬到 processing；队列空就阻塞 1 秒
                String userId = redis.opsForList()
                        .rightPopAndLeftPush(queueKey, processingKey, Duration.ofSeconds(1));
                if (userId == null) {
                    continue;
                }
                try {
                    jdbc.update(
                            "INSERT INTO `order`(goods_id, user_id) VALUES (?, ?)",
                            goodsId, Long.parseLong(userId));
                    // 写库成功，从 processing 摘掉这条，表示已消费完
                    redis.opsForList().remove(processingKey, 1, userId);
                } catch (Exception e) {
                    // 写库失败：消息留在 processing 里不丢，记日志等补偿
                    // （唯一键冲突属于重复消费，这条也应从 processing 摘掉）
                    if (isDuplicateKey(e)) {
                        redis.opsForList().remove(processingKey, 1, userId);
                        log.debug("重复消费，跳过 user={}", userId);
                    } else {
                        log.error("写订单失败，消息保留在 {} 待补偿 user={}",
                                processingKey, userId, e);
                    }
                }
            } catch (Exception e) {
                log.error("消费循环异常，1 秒后继续", e);
                sleepQuietly();
            }
        }
    }

    private boolean isDuplicateKey(Throwable e) {
        Throwable cur = e;
        while (cur != null) {
            if (cur instanceof org.springframework.dao.DuplicateKeyException) {
                return true;
            }
            cur = cur.getCause();
        }
        return false;
    }

    private void sleepQuietly() {
        try {
            Thread.sleep(1000);
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
    }
}
