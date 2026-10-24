package com.seckill.runner;

import com.seckill.service.SeckillService;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 启动命令带 --run-test 时执行两阶段验证：
 * 阶段1：1000 个不同用户抢 100 件 → 应成功 100、超卖 0。
 * 阶段2：同一个用户连抢 10 次 → 应只成功 1 次（去重生效）。
 */
@Component
public class ConcurrencyRunner implements CommandLineRunner {

    private final SeckillService service;

    public ConcurrencyRunner(SeckillService service) {
        this.service = service;
    }

    @Override
    public void run(String... args) throws Exception {
        boolean runTest = false;
        for (String a : args) {
            if ("--run-test".equals(a)) {
                runTest = true;
            }
        }
        if (!runTest) {
            return;
        }

        runPhase1();
        runPhase2();
    }

    /** 阶段1：1000 个不同用户抢 100 件 */
    private void runPhase1() throws Exception {
        System.out.println("========== 阶段1：1000 个不同用户抢 100 件 ==========");
        service.resetOrders();
        int stock = service.warmUp();
        System.out.println("预热库存: " + stock + " 件");

        int threads = 1000;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch done = new CountDownLatch(threads);
        AtomicInteger success = new AtomicInteger();

        long begin = System.currentTimeMillis();
        for (int i = 0; i < threads; i++) {
            final long userId = 1000 + i;
            pool.submit(() -> {
                try {
                    ready.countDown();
                    start.await();
                    if ("抢购成功".equals(service.seckill(userId))) {
                        success.incrementAndGet();
                    }
                } catch (Exception e) {
                    // 单个请求失败不影响整体统计
                } finally {
                    done.countDown();
                }
            });
        }
        ready.await();
        start.countDown();
        done.await();
        pool.shutdown();
        long cost = System.currentTimeMillis() - begin;
        waitQueueDrain();

        System.out.println("并发请求: " + threads);
        System.out.println("抢购成功: " + success.get());
        System.out.println("扣减耗时: " + cost + " ms");
        System.out.println("最终库存(Redis): " + service.currentStock());
        System.out.println("订单表行数: " + service.orderCount());
        System.out.println("超卖: " + Math.max(0, service.orderCount() - 100));
    }

    /** 阶段2：同一个用户连抢 10 次，只应成功 1 次 */
    private void runPhase2() throws Exception {
        System.out.println("========== 阶段2：同一个用户连抢 10 次 ==========");
        service.resetOrders();
        service.warmUp();
        int sameUserSuccess = 0;
        for (int i = 0; i < 10; i++) {
            if ("抢购成功".equals(service.seckill(9999))) {
                sameUserSuccess++;
            }
        }
        waitQueueDrain();
        System.out.println("同一用户抢购成功次数: " + sameUserSuccess + "（预期 1）");
        System.out.println("订单表行数: " + service.orderCount() + "（预期 1）");
        System.out.println("========== 验证结束 ==========");
    }

    private void waitQueueDrain() throws InterruptedException {
        // 队列空了还不够：消息可能正躺在 processing 里写库，两边都要空才算消费完
        long deadline = System.currentTimeMillis() + 15_000;
        while ((service.queueSize() > 0 || service.processingSize() > 0)
                && System.currentTimeMillis() < deadline) {
            Thread.sleep(100);
        }
    }
}
