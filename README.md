# 陪读社区 App

高考陪读家长社区平台 — "拍照知薄弱，折线看进步，社区不孤独"

## 项目简介

陪读社区是一款面向高考陪读家长的产品，将**工具（试卷分析+高考日历）**与**社区（陪读交流）**结合，帮助家长了解孩子的学习薄弱点、追踪进步轨迹，并在社区中获得情感支持和经验分享。

### 核心功能

- **试卷分析**：拍照上传试卷，OCR 自动识别对错，匹配知识图谱定位薄弱知识点
- **三档判定**：将知识点按掌握程度分为 🔴待改进 / 🟡需关注 / 🟢继续保持
- **数据看板**：历次考试得分率趋势折线图，直观追踪进步
- **高考日历**：倒计时 + 模拟考标记 + 智能提醒
- **陪读社区**：按年级/地区/科目/话题组织圈子，图文帖+问答互动
- **家长认证**：轻量级身份确认（学生证/班级群截图/缴费凭证/邀请码）

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 前端 | Flutter 3.x | 跨平台移动应用 (iOS/Android) |
| 后端 | Go + Gin | RESTful API 服务 |
| OCR 服务 | Python + FastAPI | 试卷 OCR 识别与知识图谱匹配 |
| 关系数据库 | PostgreSQL 15+ | 用户、试卷、社区等核心数据 |
| 图数据库 | Neo4j 5.x | 知识图谱存储与语义检索 |
| 缓存 | Redis 7.x | 会话、限流、验证码缓存 |
| 向量模型 | sentence-transformers | 错题文本到知识点的语义匹配 |

## 项目结构

```
peidu-community/
├── backend/                    # Go 后端服务
│   ├── cmd/server/main.go      # 服务入口
│   ├── internal/
│   │   ├── config/             # 配置管理
│   │   ├── handler/            # HTTP 处理器
│   │   ├── middleware/         # 中间件（JWT/CORS/日志）
│   │   ├── model/              # 数据模型
│   │   └── service/            # 业务逻辑层
│   ├── go.mod
│   └── go.sum
├── ocr-service/                # Python OCR 服务
│   ├── app/
│   │   ├── main.py             # FastAPI 入口
│   │   ├── ocr/                # OCR 处理模块
│   │   └── knowledge/          # 知识图谱匹配模块
│   └── requirements.txt
├── database/
│   └── schema.sql              # PostgreSQL 建表语句 + Neo4j 设计说明
├── frontend/                   # Flutter 前端（目录规划）
│   └── README.md
└── README.md                   # 本文件
```

## 快速启动

### 前置依赖

- Go 1.21+
- Python 3.10+
- PostgreSQL 15+
- Redis 7+
- Neo4j 5+（可选，知识图谱功能需要）

### 1. 数据库初始化

```bash
# 创建数据库
createdb peidu_community

# 执行建表语句
psql -d peidu_community -f database/schema.sql
```

### 2. 启动 OCR 服务

```bash
cd ocr-service
pip install -r requirements.txt
python -m app.main
# 服务启动在 http://localhost:8000
```

### 3. 启动 Go 后端

```bash
cd backend

# 配置环境变量（可选，有默认值）
export DB_PASSWORD=your_password
export JWT_SECRET=your_secret_key
export OCR_SERVICE_URL=http://localhost:8000

go run cmd/server/main.go
# 服务启动在 http://localhost:8080
```

### 4. 验证

```bash
# 健康检查
curl http://localhost:8080/api/health

# OCR 服务健康检查
curl http://localhost:8000/api/health
```

## API 接口概览

### 公开接口（无需认证）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康检查 |
| POST | `/api/auth/send-sms` | 发送短信验证码 |
| POST | `/api/auth/login` | 手机号+验证码登录 |

### 需要登录

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/users/profile` | 获取个人资料 |
| POST | `/api/users/verification` | 提交家长认证 |
| GET | `/api/users/quota` | 查询剩余分析次数 |

### 需要家长认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/papers/upload` | 上传试卷 |
| GET | `/api/papers/:id/report` | 获取分析报告 |
| GET | `/api/community/posts` | 帖子列表 |
| POST | `/api/community/posts` | 发布帖子 |

### OCR 服务

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康检查 |
| POST | `/api/ocr/analyze` | OCR 识别试卷对错 |
| POST | `/api/knowledge/match` | 知识图谱匹配 |
| POST | `/api/knowledge/batch-match` | 批量知识图谱匹配 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SERVER_PORT` | 8080 | 后端服务端口 |
| `GIN_MODE` | debug | Gin 运行模式 |
| `DB_HOST` | localhost | 数据库地址 |
| `DB_PORT` | 5432 | 数据库端口 |
| `DB_USER` | peidu | 数据库用户 |
| `DB_PASSWORD` | (空) | 数据库密码 |
| `DB_NAME` | peidu_community | 数据库名 |
| `REDIS_ADDR` | localhost:6379 | Redis 地址 |
| `NEO4J_URI` | bolt://localhost:7687 | Neo4j 地址 |
| `JWT_SECRET` | change-me-in-production | JWT 密钥 |
| `OCR_SERVICE_URL` | http://localhost:8000 | OCR 服务地址 |

## 许可证

Copyright 2025 陪读社区. All rights reserved.
