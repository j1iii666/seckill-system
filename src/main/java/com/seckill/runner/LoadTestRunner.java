package com.seckill.runner;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 第 6 课：真实 HTTP 压测器。
 * 启动命令带 --loadtest 时，Spring Boot 正常起 web（8081），
 * 本类用 Java 自带的 HttpClient 并发打自己的 /api/seckill，统计 QPS。
 */
@Component
public class LoadTestRunner implements CommandLineRunner {

    @Value("${server.port:8081}")
    private int port;

    @Override
    public void run(String... args) throws Exception {
        boolean run = false;
        for (String a : args) {
            if ("--loadtest".equals(a)) {
                run = true;
            }
        }
        if (!run) {
            return;
        }

        String base = "http://127.0.0.1:" + port;
        HttpClient client = HttpClient.newBuilder()
                .version(HttpClient.Version.HTTP_1_1)
                .connectTimeout(Duration.ofSeconds(5))
                .build();

        // 先预热（POST /api/init）
        HttpRequest init = HttpRequest.newBuilder(URI.create(base + "/api/init"))
                .POST(HttpRequest.BodyPublishers.noBody())
                .build();
        client.send(init, HttpResponse.BodyHandlers.ofString());
        System.out.println("预热完成，开始压测...");

        int n = 1000;
        // 客户端与被压服务在同一 JVM，1000 个连接同时建会互相抢资源；
        // 用 200 并发排队发 1000 个请求，测稳定 QPS
        int concurrency = 200;
        ExecutorService pool = Executors.newFixedThreadPool(concurrency);
        // 关键：只有 concurrency 个线程能同时执行，栅栏就等 concurrency 个，
        // 写错成 n 会导致剩下 800 个任务永远排不上队 → 死锁
        CountDownLatch ready = new CountDownLatch(concurrency);
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch done = new CountDownLatch(n);
        AtomicInteger ok = new AtomicInteger();
        AtomicInteger err = new AtomicInteger();

        long t0 = System.currentTimeMillis();
        for (int i = 0; i < n; i++) {
            final long userId = 2000 + i;
            pool.submit(() -> {
                try {
                    ready.countDown();
                    start.await();
                    HttpRequest req = HttpRequest.newBuilder(
                                    URI.create(base + "/api/seckill?userId=" + userId))
                            .timeout(Duration.ofSeconds(10))
                            .GET().build();
                    HttpResponse<String> resp = client.send(req, HttpResponse.BodyHandlers.ofString());
                    if (resp.body().contains("\"code\":0")) {
                        ok.incrementAndGet();
                    }
                } catch (Exception e) {
                    err.incrementAndGet();
                } finally {
                    done.countDown();
                }
            });
        }
        ready.await();
        start.countDown();
        done.await();
        pool.shutdown();
        long dur = System.currentTimeMillis() - t0;

        System.out.println("========== 压测结果 ==========");
        System.out.println("请求数: " + n);
        System.out.println("并发数: " + concurrency);
        System.out.println("总耗时: " + dur + " ms");
        System.out.println("QPS: " + String.format("%.1f", n * 1000.0 / dur));
        System.out.println("抢购成功: " + ok.get());
        System.out.println("请求异常: " + err.get());
        System.out.println("========== 压测结束 ==========");

        // 压测是命令行一次性任务，打印完直接退出
        System.exit(0);
    }
}
