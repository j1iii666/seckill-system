"""
秒杀压测脚本（第 6 课）
用法：python scripts/loadtest.py [请求数] [并发数]
例子：python scripts/loadtest.py 1000 500

做的事：预热库存 -> 并发打抢购接口 -> 统计 QPS / 成功率 -> 查最终库存和订单数
"""
import concurrent.futures
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:8081"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
WORKERS = int(sys.argv[2]) if len(sys.argv) > 2 else 500


def post(path):
    req = urllib.request.Request(BASE + path, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode()


def get(path):
    with urllib.request.urlopen(BASE + path, timeout=30) as r:
        return r.read().decode()


def hit(i):
    try:
        return get(f"/api/seckill?userId={i}")
    except Exception:
        return '{"code":1,"msg":"ERR"}'


def main():
    print("预热:", post("/api/init"))

    t0 = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as ex:
        results = list(ex.map(hit, range(1, N + 1)))
    dur = time.time() - t0

    ok = sum(1 for r in results if '"code":0' in r)
    print(f"请求数={N}  并发={WORKERS}")
    print(f"总耗时={dur:.2f}s  QPS={N / dur:.1f}  成功={ok}")
    print("最终状态:", get("/api/status"))


if __name__ == "__main__":
    main()
