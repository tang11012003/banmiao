"""
陪读社区 OCR 服务 - FastAPI 入口

提供以下接口：
- POST /api/ocr/analyze     OCR 识别试卷对错
- POST /api/knowledge/match  知识图谱匹配
- POST /api/knowledge/batch-match  批量知识图谱匹配
- GET  /health               健康检查
"""

import io
import logging
import sys
from typing import List, Optional

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from PIL import Image

from app.ocr.processor import OCRProcessor
from app.knowledge.matcher import KnowledgeMatcher

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("ocr-service")

app = FastAPI(
    title="陪读社区 OCR 服务",
    description="试卷 OCR 识别与知识图谱匹配服务",
    version="1.0.0",
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 初始化处理器
ocr_processor = OCRProcessor()
knowledge_matcher = KnowledgeMatcher()


# ============ 数据模型 ============

class QuestionItem(BaseModel):
    """单道题结果"""
    question_num: int = Field(description="题号")
    text: str = Field(description="题目文本")
    status: str = Field(description="对错状态: correct/wrong/half/unanswered")
    max_score: float = Field(default=0, description="满分")
    actual_score: float = Field(default=0, description="实际得分")
    confidence: float = Field(default=0.0, description="OCR 识别置信度")


class OCRAnalyzeResponse(BaseModel):
    """OCR 分析响应"""
    success: bool = True
    total_questions: int = Field(description="总题数")
    correct_count: int = Field(description="正确题数")
    wrong_count: int = Field(description="错误题数")
    half_count: int = Field(default=0, description="半对题数")
    unanswered_count: int = Field(default=0, description="未作答题数")
    score_rate: float = Field(default=0.0, description="得分率")
    questions: List[QuestionItem] = Field(default_factory=list)
    message: str = ""


class MatchRequest(BaseModel):
    """知识图谱匹配请求"""
    question_text: str = Field(description="错题文本")
    subject: str = Field(default="", description="科目，如：数学、物理、化学")
    top_k: int = Field(default=3, ge=1, le=10, description="返回 Top K 个匹配结果")
    threshold: float = Field(default=0.7, ge=0.0, le=1.0, description="相似度阈值")


class MatchResult(BaseModel):
    """单条匹配结果"""
    knowledge_point_id: int
    name: str
    similarity: float
    matched: bool


class MatchResponse(BaseModel):
    """知识图谱匹配响应"""
    success: bool = True
    results: List[MatchResult] = Field(default_factory=list)
    message: str = ""


class BatchMatchRequest(BaseModel):
    """批量匹配请求"""
    questions: List[dict] = Field(description="错题列表 [{\"text\": \"...\"}, ...]")
    subject: str = Field(default="", description="科目")
    top_k: int = Field(default=3, ge=1, le=10, description="返回 Top K 个匹配结果")
    threshold: float = Field(default=0.7, ge=0.0, le=1.0, description="相似度阈值")


class BatchMatchResponse(BaseModel):
    """批量匹配响应"""
    success: bool = True
    results: List[List[MatchResult]] = Field(default_factory=list)
    message: str = ""


# ============ 异常处理 ============

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """全局异常处理"""
    logger.error(f"未捕获的异常: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"success": False, "message": f"服务内部错误: {str(exc)}"},
    )


# ============ 接口 ============

@app.get("/health")
async def health_check():
    """健康检查"""
    return {
        "status": "ok",
        "service": "ocr-service",
        "version": "1.0.0",
    }


@app.post("/api/ocr/analyze")
async def analyze_paper(
    file: UploadFile = File(description="试卷图片，支持 JPG/PNG/PDF"),
):
    """
    OCR 识别试卷对错

    接收试卷图片，返回每道题的对错状态。
    支持单页和多页上传。
    """
    # 校验文件类型
    allowed_types = ["image/jpeg", "image/png", "image/jpg"]
    if file.content_type and file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail="不支持的文件格式，请上传 JPG/PNG 格式的试卷图片",
        )

    try:
        contents = await file.read()

        if len(contents) == 0:
            raise HTTPException(status_code=400, detail="上传的文件为空")

        image = Image.open(io.BytesIO(contents))

        # 限制图片大小，防止内存溢出
        max_dimension = 4096
        if image.width > max_dimension or image.height > max_dimension:
            ratio = max_dimension / max(image.width, image.height)
            new_size = (int(image.width * ratio), int(image.height * ratio))
            image = image.resize(new_size, Image.LANCZOS)
            logger.info(f"图片过大，已缩放至 {new_size}")

        logger.info(f"开始分析试卷，图片尺寸: {image.width}x{image.height}")

        # 调用 OCR 处理器
        questions = ocr_processor.analyze_paper(image)

        # 统计
        total = len(questions)
        correct = sum(1 for q in questions if q["status"] == "correct")
        wrong = sum(1 for q in questions if q["status"] == "wrong")
        half = sum(1 for q in questions if q["status"] == "half")
        unanswered = sum(1 for q in questions if q["status"] == "unanswered")

        # 计算得分率
        total_max_score = sum(q["max_score"] for q in questions)
        total_actual_score = sum(q["actual_score"] for q in questions)
        score_rate = round(total_actual_score / total_max_score, 4) if total_max_score > 0 else 0.0

        logger.info(
            f"识别完成: 总题数={total}, 正确={correct}, "
            f"错误={wrong}, 半对={half}, 未作答={unanswered}, "
            f"得分率={score_rate:.2%}"
        )

        return JSONResponse(content={
            "success": True,
            "total_questions": total,
            "correct_count": correct,
            "wrong_count": wrong,
            "half_count": half,
            "unanswered_count": unanswered,
            "score_rate": score_rate,
            "questions": [QuestionItem(**q).model_dump() for q in questions],
            "message": "识别完成",
        })

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"OCR 识别失败: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "total_questions": 0,
                "correct_count": 0,
                "wrong_count": 0,
                "half_count": 0,
                "unanswered_count": 0,
                "score_rate": 0.0,
                "questions": [],
                "message": f"识别失败: {str(e)}",
            },
        )


@app.post("/api/knowledge/match")
async def match_knowledge(request: MatchRequest):
    """
    知识图谱匹配

    接收错题文本和科目，返回匹配的知识点。
    """
    try:
        logger.info(f"知识匹配: subject={request.subject}, text={request.question_text[:50]}...")

        results = knowledge_matcher.match(
            question_text=request.question_text,
            subject=request.subject,
            top_k=request.top_k,
            threshold=request.threshold,
        )

        return JSONResponse(content={
            "success": True,
            "results": [MatchResult(**r).model_dump() for r in results],
            "message": "匹配完成",
        })

    except Exception as e:
        logger.error(f"知识匹配失败: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "results": [],
                "message": f"匹配失败: {str(e)}",
            },
        )


@app.post("/api/knowledge/batch-match")
async def batch_match_knowledge(request: BatchMatchRequest):
    """
    批量知识图谱匹配

    接收多个错题文本，批量匹配知识点。
    """
    try:
        if not request.questions:
            raise HTTPException(status_code=400, detail="错题列表不能为空")

        logger.info(f"批量匹配: subject={request.subject}, 题目数={len(request.questions)}")

        results = knowledge_matcher.batch_match(
            questions=request.questions,
            subject=request.subject,
            top_k=request.top_k,
            threshold=request.threshold,
        )

        return JSONResponse(content={
            "success": True,
            "results": [
                [MatchResult(**r).model_dump() for r in batch]
                for batch in results
            ],
            "message": f"批量匹配完成，共 {len(results)} 道题",
        })

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量匹配失败: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "results": [],
                "message": f"批量匹配失败: {str(e)}",
            },
        )


if __name__ == "__main__":
    import uvicorn
    import os
    # 确保当前目录在 Python 路径中
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    logger.info("启动 OCR 服务，监听端口 8001")
    uvicorn.run("app.main:app", host="0.0.0.0", port=8001, reload=False)
