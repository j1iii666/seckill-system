-- 秒杀系统：建库 + 建表 + 商品数据（幂等，可重复执行）
-- 注意：应用用户（seckill）的创建和密码不在这里，由 init-db.bat 交互式设置，
--       避免把密码写进仓库。数据库账号密码在 application-local.yml 里配置。
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

DELETE FROM goods;
INSERT INTO goods (name, stock, price) VALUES ('可达鸭（测试商品）', 100, 19999.00);

SELECT 'INIT_OK' AS result, COUNT(*) AS goods_count FROM goods;
