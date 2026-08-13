#!/usr/bin/env bash
#
# 陪读社区 OCR 服务 - 启动脚本
#
# 功能：
# 1. 检查 Python 环境
# 2. 安装依赖
# 3. 启动 OCR 服务
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "  陪读社区 OCR 服务 - 启动脚本"
echo "========================================="

# 检查 Python 版本
PYTHON_CMD=""
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
else
    echo "[ERROR] 未找到 Python，请安装 Python 3.8+"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo "[INFO] Python 版本: $PYTHON_VERSION"

# 创建虚拟环境（可选）
if [ ! -d "venv" ]; then
    echo "[INFO] 创建虚拟环境..."
    $PYTHON_CMD -m venv venv
fi

# 激活虚拟环境
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "[INFO] 已激活虚拟环境"
fi

# 安装依赖
echo "[INFO] 安装依赖..."
pip install -r requirements.txt -q

# 检查关键依赖
echo "[INFO] 检查关键依赖..."
$PYTHON_CMD -c "import fastapi; print('  fastapi:', fastapi.__version__)"
$PYTHON_CMD -c "import uvicorn; print('  uvicorn:', uvicorn.__version__)"
$PYTHON_CMD -c "import PIL; print('  Pillow:', PIL.__version__)"
$PYTHON_CMD -c "import numpy; print('  numpy:', numpy.__version__)"
$PYTHON_CMD -c "import sklearn; print('  scikit-learn:', sklearn.__version__)"

# 检查知识图谱文件
KG_PATH="../database/knowledge_graph.json"
if [ -f "$KG_PATH" ]; then
    echo "[INFO] 知识图谱文件已找到: $KG_PATH"
else
    echo "[WARN] 知识图谱文件未找到: $KG_PATH"
    echo "      知识图谱匹配功能将返回空结果"
fi

echo ""
echo "========================================="
echo "  启动 OCR 服务 (端口: 8001)"
echo "========================================="
echo "  接口文档: http://localhost:8001/docs"
echo "  健康检查: http://localhost:8001/health"
echo "  Ctrl+C 停止服务"
echo "========================================="
echo ""

# 启动服务
$PYTHON_CMD -m uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
