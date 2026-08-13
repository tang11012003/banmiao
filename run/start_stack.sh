#!/usr/bin/env bash
# 陪读社区体验环境：单入口启动脚本（幂等，供 supervisord 托管）
# 负责：释放端口 -> 确保 PostgreSQL(docker) -> 起 OCR -> 起后端 -> 前台跑反代(8081)
set -u

export PATH="/root/.pyenv/versions/3.11.1/bin:$PATH"
WORK=/workspace/peidu-community
OCR_DIR=${WORK}/ocr-service
BACKEND_BIN=${WORK}/backend/bin/peidu-backend
PROXY=${WORK}/run/web_proxy.py

# 后端连接数据库所需环境变量（docker 已将 5432 映射到本机 localhost）
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=peidu123
export DB_NAME=peidu_community
export GIN_MODE=release

# ---- 1. 释放可能冲突的端口（清理上一轮孤儿进程，保证可重复重启）----
for p in 8000 8080 8081; do
  fuser -k ${p}/tcp 2>/dev/null || true
done
sleep 1

# ---- 2. PostgreSQL（docker）----
if ! docker ps -a --format '{{.Names}}' | grep -qx peidu_pg; then
  echo "[stack] 重建 peidu_pg 容器"
  docker run -d --name peidu_pg --restart unless-stopped \
    -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=peidu123 -e POSTGRES_DB=peidu_community \
    -p 5432:5432 postgres:15-alpine
else
  docker update --restart unless-stopped peidu_pg >/dev/null 2>&1 || true
  docker start peidu_pg >/dev/null 2>&1 || true
fi
# 等待数据库就绪（最多 30s）
for i in $(seq 1 30); do
  if docker exec peidu_pg pg_isready -U postgres >/dev/null 2>&1; then
    echo "[stack] PostgreSQL 就绪"
    break
  fi
  sleep 1
done

# ---- 3. OCR 服务（8000）----
cd ${OCR_DIR}
echo "[stack] 启动 OCR(8000)"
python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 >/tmp/peidu-ocr.log 2>&1 &

# ---- 4. 后端（8080）----
echo "[stack] 启动后端(8080)"
${BACKEND_BIN} >/tmp/peidu-backend.log 2>&1 &

# 给后端/OCR 一点启动时间
sleep 3

# ---- 5. 前台运行反代（supervisord 实际托管对象，exec 替换为同一 PID）----
echo "[stack] 前台运行反代(8081)"
exec python3.11 ${PROXY}
