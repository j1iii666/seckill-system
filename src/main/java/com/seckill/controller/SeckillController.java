package com.seckill.controller;

import com.seckill.service.SeckillService;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class SeckillController {

    private final SeckillService service;

    public SeckillController(SeckillService service) {
        this.service = service;
    }

    /** 预热库存：把 MySQL 的 100 件推进 Redis */
    @PostMapping("/init")
    public Map<String, Object> init() {
        int stock = service.warmUp();
        return Map.of("code", 0, "stock", stock, "msg", "预热完成");
    }

    /** 重置：清订单、清 Redis 库存/队列/去重集合，方便反复演示 */
    @PostMapping("/reset")
    public Map<String, Object> reset() {
        service.resetOrders();
        return Map.of("code", 0, "msg", "已重置");
    }

    /** 抢购（GET/POST 都支持，GET 方便压测工具直接打 URL） */
    @RequestMapping(value = "/seckill", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> seckill(@RequestParam long userId) {
        String msg = service.seckill(userId);
        return Map.of("code", msg.equals("抢购成功") ? 0 : 1, "msg", msg);
    }

    /** 当前 Redis 库存 + 已落库订单数 + 队列剩余 */
    @GetMapping("/status")
    public Map<String, Object> status() {
        Map<String, Object> m = new HashMap<>();
        m.put("stock", service.currentStock());
        m.put("orders", service.orderCount());
        m.put("queue", service.queueSize());
        return m;
    }
}
