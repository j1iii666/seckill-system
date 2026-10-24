-- 秒杀系统建库建表脚本（在 MySQL 里执行一次）
CREATE DATABASE IF NOT EXISTS seckill DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE seckill;

CREATE TABLE IF NOT EXISTS goods (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    stock       INT NOT NULL DEFAULT 0,
    price       DECIMAL(10,2) NOT NULL DEFAULT 0,
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `order` (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    goods_id    BIGINT NOT NULL,
    user_id     BIGINT NOT NULL,
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_goods_user (goods_id, user_id)
) ENGINE=InnoDB;

-- 一件商品，库存 100 件
INSERT INTO goods (name, stock, price) VALUES ('茅台生肖酒（测试商品）', 100, 2999.00);
