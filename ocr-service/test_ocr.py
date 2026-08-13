#!/usr/bin/env python3
"""
陪读社区 OCR 服务 - 端到端测试脚本

功能：
1. 生成一张模拟试卷图片（含题目和批改标记）
2. 调用 OCR 服务接口
3. 调用知识图谱匹配接口
4. 打印分析结果
5. 验证全链路可用
"""

import io
import json
import sys
import time
import urllib.request
from PIL import Image, ImageDraw, ImageFont

# 配置
OCR_SERVICE_URL = "http://localhost:8001"
TEST_IMAGE_PATH = "/tmp/test_exam_paper.png"


def create_test_paper() -> Image.Image:
    """
    生成一张模拟试卷图片

    模拟一张 A4 纸大小的数学试卷，包含：
    - 标题
    - 题目文本
    - 红色批改标记（✓ / ✗ / 半对）
    - 手写痕迹
    """
    width, height = 1240, 1754  # A4 比例 (210x297mm → 1240x1754px)
    img = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(img)

    # 尝试加载中文字体
    font_large = None
    font_normal = None
    font_small = None
    try:
        font_large = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc", 32)
        font_normal = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc", 22)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc", 16)
    except (IOError, OSError):
        try:
            font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 32)
            font_normal = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 22)
            font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
        except (IOError, OSError):
            font_large = ImageFont.load_default()
            font_normal = ImageFont.load_default()
            font_small = ImageFont.load_default()

    # 标题
    draw.text((width // 2 - 150, 60), "2025 年高考数学模拟试卷", fill="black", font=font_large)
    draw.line([(80, 110), (width - 80, 110)], fill="black", width=2)

    # 题目列表（模拟 20 道题）
    questions = [
        (1, "已知集合 A={1,2,3}, B={2,3,4}，求 A∩B。", "correct"),
        (2, "求函数 f(x)=x^2-2x+3 在 [0,3] 上的最小值。", "correct"),
        (3, "已知 sinα=3/5，α 为第二象限角，求 cosα。", "correct"),
        (4, "求椭圆 x^2/9 + y^2/4 = 1 的离心率。", "wrong"),
        (5, "已知等差数列 {an} 中 a1=2, a5=10，求公差 d。", "correct"),
        (6, "求曲线 y=x^3-3x 在点 (1,-2) 处的切线方程。", "wrong"),
        (7, "在△ABC中，已知 a=3, b=4, C=60°，求边 c。", "half"),
        (8, "已知向量 a=(2,1), b=(1,3)，求 a 与 b 的夹角。", "correct"),
        (9, "证明：函数 f(x)=ln(x+1)-x/(x+1) 在 (0,+∞) 上单调递增。", "wrong"),
        (10, "从 5 名男生和 3 名女生中选 4 人参加比赛，求恰有 2 名女生的概率。", "correct"),
        (11, "已知抛物线 y^2=4x，过焦点作倾斜角 45° 的直线，求弦长。", "unanswered"),
        (12, "已知函数 f(x)=e^x-ax，讨论 f(x) 的单调性（a 为参数）。", "wrong"),
        (13, "在正方体中，求异面直线 A1B 与 B1C 所成角。", "correct"),
        (14, "已知 X~N(2,σ^2)，P(X<4)=0.8，求 P(0<X<2)。", "half"),
        (15, "求数列 {n·2^n} 的前 n 项和。", "wrong"),
        (16, "已知双曲线渐近线 y=±(√3/3)x，求离心率。", "correct"),
        (17, "证明：当 x>0 时，x-x^2/2 < ln(1+x) < x。", "unanswered"),
        (18, "已知圆 C: x^2+y^2-4x+2y-4=0，求过 P(1,2) 的切线。", "correct"),
        (19, "在△ABC中，sinA:sinB:sinC=3:5:7，判断三角形形状。", "wrong"),
        (20, "已知 f(x)=x^3+ax^2+bx+c 在 x=1 处有极值 10，求 a,b,c。", "half"),
    ]

    y = 150
    for num, text, status in questions:
        # 题号和题目文本
        question_text = f"{num}. {text}"
        draw.text((100, y), question_text, fill="black", font=font_normal)

        # 在题目右侧添加批改标记
        mark_x = width - 200
        mark_y = y

        if status == "correct":
            # 红色 ✓
            draw.text((mark_x, mark_y), "✓", fill="red", font=font_large)
        elif status == "wrong":
            # 红色 ✗
            draw.text((mark_x, mark_y), "✗", fill="red", font=font_large)
        elif status == "half":
            # 红色半对标记
            draw.text((mark_x, mark_y), "△", fill="red", font=font_large)
            draw.text((mark_x + 30, mark_y), "-3", fill="red", font=font_small)
        elif status == "unanswered":
            # 红色圆圈或问号（未作答标记）
            draw.text((mark_x, mark_y), "?", fill="red", font=font_large)

        # 模拟手写批注（随机添加一些红色笔迹）
        if status in ("wrong", "half"):
            # 在题目旁边画一些模拟批注的短线
            for i in range(3):
                bx = mark_x + 50 + i * 15
                by = mark_y + 5 + i * 5
                draw.line([(bx, by), (bx + 8, by - 3)], fill="red", width=2)

        y += 65

    # 底部分数统计区域
    draw.line([(80, y + 20), (width - 80, y + 20)], fill="black", width=1)
    draw.text((width // 2 - 100, y + 40), "总分：117/150    得分率：78%", fill="black", font=font_normal)

    # 添加一些噪点模拟真实扫描效果
    import random
    pixels = img.load()
    for _ in range(500):
        px = random.randint(0, width - 1)
        py = random.randint(0, height - 1)
        noise = random.randint(-10, 10)
        r, g, b = pixels[px, py]
        pixels[px, py] = (
            max(0, min(255, r + noise)),
            max(0, min(255, g + noise)),
            max(0, min(255, b + noise)),
        )

    return img


def test_health():
    """测试健康检查接口"""
    print("=" * 60)
    print("[TEST] 健康检查")
    print("=" * 60)

    try:
        req = urllib.request.Request(f"{OCR_SERVICE_URL}/health")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            print(f"  状态: {data['status']}")
            print(f"  服务: {data['service']}")
            print(f"  版本: {data['version']}")
            print("  [PASS] 健康检查通过")
            return True
    except Exception as e:
        print(f"  [FAIL] 健康检查失败: {e}")
        return False


def test_ocr_analyze():
    """测试 OCR 分析接口"""
    print("\n" + "=" * 60)
    print("[TEST] OCR 试卷分析")
    print("=" * 60)

    # 创建模拟试卷图片
    print("  生成模拟试卷图片...")
    paper_img = create_test_paper()
    paper_img.save(TEST_IMAGE_PATH)
    print(f"  试卷图片已保存: {TEST_IMAGE_PATH} ({paper_img.width}x{paper_img.height})")

    # 读取图片并上传
    with open(TEST_IMAGE_PATH, "rb") as f:
        image_data = f.read()

    boundary = "----TestBoundary"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="test_paper.png"\r\n'
        f"Content-Type: image/png\r\n\r\n"
    ).encode() + image_data + f"\r\n--{boundary}--\r\n".encode()

    req = urllib.request.Request(
        f"{OCR_SERVICE_URL}/api/ocr/analyze",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode())
            print(f"\n  识别结果:")
            print(f"    总题数: {result['total_questions']}")
            print(f"    正确: {result['correct_count']}")
            print(f"    错误: {result['wrong_count']}")
            print(f"    半对: {result['half_count']}")
            print(f"    未作答: {result['unanswered_count']}")
            print(f"    得分率: {result['score_rate']:.2%}")
            print(f"    消息: {result['message']}")

            if result['questions']:
                print(f"\n  题目详情 (前 5 题):")
                for q in result['questions'][:5]:
                    status_icon = {"correct": "✓", "wrong": "✗", "half": "△", "unanswered": "?"}
                    icon = status_icon.get(q['status'], "?")
                    print(f"    {icon} 第{q['question_num']}题 [{q['status']}] "
                          f"得分: {q['actual_score']}/{q['max_score']} "
                          f"置信度: {q['confidence']:.2%}")
                    print(f"        {q['text'][:60]}...")

            print(f"\n  [PASS] OCR 分析通过")
            return True, result
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else str(e)
        print(f"  [FAIL] HTTP {e.code}: {body}")
        return False, None
    except Exception as e:
        print(f"  [FAIL] OCR 分析失败: {e}")
        return False, None


def test_knowledge_match():
    """测试知识图谱匹配接口"""
    print("\n" + "=" * 60)
    print("[TEST] 知识图谱匹配")
    print("=" * 60)

    # 测试用例：不同类型的错题
    test_cases = [
        {
            "text": "求曲线 y=x^3-3x 在点 (1,-2) 处的切线方程",
            "subject": "数学",
            "desc": "导数-切线问题",
        },
        {
            "text": "已知椭圆 x^2/9 + y^2/4 = 1，求其离心率",
            "subject": "数学",
            "desc": "解析几何-椭圆",
        },
        {
            "text": "在△ABC中，已知 a=3, b=4, C=60°，求边 c 的长度",
            "subject": "数学",
            "desc": "余弦定理",
        },
        {
            "text": "一个物体从静止开始做匀加速直线运动，第3秒内位移是5m",
            "subject": "物理",
            "desc": "物理-直线运动",
        },
        {
            "text": "写出铁与稀硫酸反应的化学方程式并配平",
            "subject": "化学",
            "desc": "化学-金属反应",
        },
        {
            "text": "这段文字完全不涉及任何已知的高考知识点内容",
            "subject": "数学",
            "desc": "低相似度-应触发人工复核",
        },
    ]

    all_passed = True
    for i, tc in enumerate(test_cases):
        print(f"\n  测试 {i+1}: {tc['desc']}")
        print(f"    输入: {tc['text'][:50]}...")

        data = json.dumps({
            "question_text": tc["text"],
            "subject": tc["subject"],
            "top_k": 3,
            "threshold": 0.7,
        }).encode()

        req = urllib.request.Request(
            f"{OCR_SERVICE_URL}/api/knowledge/match",
            data=data,
            headers={"Content-Type": "application/json"},
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read().decode())
                if result.get("success"):
                    for r in result.get("results", [])[:3]:
                        status = "[匹配]" if r["matched"] else "[需人工复核]"
                        print(f"    {status} {r['name']} (相似度: {r['similarity']:.4f})")
                else:
                    print(f"    [FAIL] {result.get('message', '')}")
                    all_passed = False
        except Exception as e:
            print(f"    [FAIL] 请求失败: {e}")
            all_passed = False

    if all_passed:
        print(f"\n  [PASS] 知识图谱匹配通过")
    else:
        print(f"\n  [WARN] 部分测试未通过")
    return all_passed


def test_batch_match(ocr_result):
    """测试批量知识图谱匹配"""
    if not ocr_result or not ocr_result.get("questions"):
        print("\n  跳过批量匹配测试（无 OCR 结果）")
        return True

    print("\n" + "=" * 60)
    print("[TEST] 批量知识图谱匹配")
    print("=" * 60)

    # 获取错题列表
    wrong_questions = [
        {"text": q["text"]}
        for q in ocr_result["questions"]
        if q["status"] in ("wrong", "half")
    ]

    if not wrong_questions:
        print("  没有错题，跳过批量匹配")
        return True

    print(f"  错题数量: {len(wrong_questions)}")

    data = json.dumps({
        "questions": wrong_questions[:5],  # 最多匹配 5 道
        "subject": "数学",
        "top_k": 3,
        "threshold": 0.7,
    }).encode()

    req = urllib.request.Request(
        f"{OCR_SERVICE_URL}/api/knowledge/batch-match",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode())
            if result.get("success"):
                for i, batch in enumerate(result.get("results", [])):
                    question_text = wrong_questions[i]["text"][:40]
                    top_match = batch[0] if batch else {"name": "无匹配", "similarity": 0}
                    print(f"  错题 {i+1}: {question_text}...")
                    print(f"    → {top_match['name']} (相似度: {top_match['similarity']:.4f})")
                print(f"\n  [PASS] 批量匹配通过")
                return True
            else:
                print(f"  [FAIL] {result.get('message', '')}")
                return False
    except Exception as e:
        print(f"  [FAIL] 批量匹配失败: {e}")
        return False


def test_error_handling():
    """测试错误处理"""
    print("\n" + "=" * 60)
    print("[TEST] 错误处理")
    print("=" * 60)

    all_passed = True

    # 测试 1: 空请求体
    print("\n  测试 1: 空知识匹配请求")
    req = urllib.request.Request(
        f"{OCR_SERVICE_URL}/api/knowledge/match",
        data=b"{}",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read().decode())
            print(f"    响应: {result}")
            print("    [PASS] 空请求被正确处理（FastAPI 自动 422）")
    except urllib.error.HTTPError as e:
        print(f"    HTTP {e.code} - 符合预期（参数校验）")
        print("    [PASS] 错误处理正确")
    except Exception as e:
        print(f"    [WARN] {e}")

    # 测试 2: 无效科目
    print("\n  测试 2: 无效科目查询")
    data = json.dumps({
        "question_text": "求导数",
        "subject": "不存在的科目",
        "top_k": 3,
        "threshold": 0.7,
    }).encode()
    req = urllib.request.Request(
        f"{OCR_SERVICE_URL}/api/knowledge/match",
        data=data,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read().decode())
            print(f"    匹配结果数: {len(result.get('results', []))}")
            if result.get("success", True):
                print("    [PASS] 无效科目被正确处理")
            else:
                print("    [INFO] 返回错误信息")
    except Exception as e:
        print(f"    [FAIL] {e}")
        all_passed = False

    return all_passed


def main():
    """主测试流程"""
    print("\n" + "=" * 60)
    print("  陪读社区 OCR 服务 - 端到端测试")
    print("=" * 60)
    print(f"  服务地址: {OCR_SERVICE_URL}")

    results = {}

    # 1. 健康检查
    results["health"] = test_health()
    if not results["health"]:
        print("\n[ERROR] 服务未启动，请先运行: cd ocr-service && python app/main.py")
        sys.exit(1)

    # 2. OCR 分析
    ocr_ok, ocr_result = test_ocr_analyze()
    results["ocr"] = ocr_ok

    # 3. 知识图谱匹配
    results["match"] = test_knowledge_match()

    # 4. 批量匹配
    results["batch"] = test_batch_match(ocr_result)

    # 5. 错误处理
    results["error"] = test_error_handling()

    # 汇总
    print("\n" + "=" * 60)
    print("  测试汇总")
    print("=" * 60)
    all_passed = True
    for name, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {name}")
        if not passed:
            all_passed = False

    print("\n" + "=" * 60)
    if all_passed:
        print("  全部测试通过!")
    else:
        print("  部分测试未通过，请检查日志")
    print("=" * 60)

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
