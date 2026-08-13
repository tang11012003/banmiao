"""
OCR 处理模块

负责：
1. 图像预处理（灰度化、二值化、去噪、倾斜校正）
2. 模拟 OCR 识别：基于图像特征生成合理的模拟结果
3. 支持多页图片处理

由于无法接入真实 OCR API，本模块通过分析图像特征（红色区域、手写痕迹等）
生成合理的模拟识别结果，覆盖全对、有错、未作答等多种场景。
"""

import random
from typing import List, Dict, Any, Optional, Tuple
from PIL import Image, ImageFilter, ImageOps, ImageEnhance
import numpy as np


class ImagePreprocessor:
    """图像预处理器 - 提高 OCR 识别质量的预处理步骤"""

    def preprocess(self, image: Image.Image) -> Image.Image:
        """
        预处理图像：灰度化 → 增强对比度 → 二值化 → 去噪 → 倾斜校正

        Args:
            image: PIL Image 对象

        Returns:
            预处理后的 PIL Image 对象
        """
        # 1. 转为灰度图
        if image.mode != "L":
            image = image.convert("L")

        # 2. 对比度增强
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(1.8)

        # 3. 锐化以增强文字边缘
        image = image.filter(ImageFilter.SHARPEN)

        # 4. 自适应二值化（基于 Otsu 阈值的简化实现）
        image = self._adaptive_threshold(image)

        # 5. 去噪（中值滤波）
        image = image.filter(ImageFilter.MedianFilter(size=3))

        # 6. 倾斜校正
        image = self._deskew(image)

        return image

    def _adaptive_threshold(self, image: Image.Image) -> Image.Image:
        """基于 Otsu 方法的自适应二值化"""
        img_array = np.array(image, dtype=np.float32)

        # 计算 Otsu 阈值
        hist, _ = np.histogram(img_array.flatten(), bins=256, range=[0, 256])
        total = hist.sum()
        if total == 0:
            return image

        sum_b = 0
        w_b = 0
        maximum = 0.0
        threshold = 127
        sum_total = (np.arange(256) * hist).sum()

        for i in range(256):
            w_b += hist[i]
            if w_b == 0:
                continue
            w_f = total - w_b
            if w_f == 0:
                break
            sum_b += i * hist[i]
            m_b = sum_b / w_b
            m_f = (sum_total - sum_b) / w_f
            between = w_b * w_f * ((m_b - m_f) ** 2)
            if between > maximum:
                maximum = between
                threshold = i

        # 应用阈值
        binary = (img_array > threshold).astype(np.uint8) * 255
        return Image.fromarray(binary)

    def _deskew(self, image: Image.Image) -> Image.Image:
        """
        倾斜校正 - 基于投影轮廓的方法

        检测文本行的倾斜角度并进行旋转校正。
        如果倾斜角度很小（< 0.3度），不做校正以避免不必要的旋转。
        """
        img_array = np.array(image, dtype=np.uint8)

        # 计算倾斜角度（基于投影的简化方法）
        angle = self._estimate_skew_angle(img_array)

        if abs(angle) < 0.3:
            return image

        # 旋转校正
        return image.rotate(angle, resample=Image.BICUBIC, fillcolor=255)

    def _estimate_skew_angle(self, img_array: np.ndarray) -> float:
        """
        估算图像倾斜角度

        通过分析水平投影的方差来估计旋转角度。
        返回角度值（度数），正值表示逆时针旋转。
        """
        # 简化实现：对于模拟环境，随机返回一个小角度或 0
        # 在实际 OCR 系统中，这里会使用 Hough 变换或投影轮廓法
        h, w = img_array.shape

        # 使用水平投影分析
        # 将图像反转（黑底白字 → 白底黑字更方便处理）
        binary = (img_array < 128).astype(np.uint8)

        best_angle = 0.0
        max_variance = 0.0

        # 在小角度范围内搜索最佳角度
        for angle in np.arange(-2.0, 2.1, 0.5):
            rotated = self._rotate_image(binary, angle)
            # 计算水平投影的方差
            projection = rotated.sum(axis=1)
            variance = np.var(projection)
            if variance > max_variance:
                max_variance = variance
                best_angle = angle

        return best_angle

    def _rotate_image(self, img_array: np.ndarray, angle: float) -> np.ndarray:
        """旋转二值图像（用于倾斜检测）"""
        if angle == 0:
            return img_array
        pil_img = Image.fromarray(img_array.astype(np.uint8) * 255)
        rotated = pil_img.rotate(angle, resample=Image.BICUBIC, fillcolor=0)
        return (np.array(rotated) > 128).astype(np.uint8)


class OCRProcessor:
    """
    OCR 处理器 - 模拟识别试卷对错

    由于无法接入真实 OCR API，本处理器通过分析图像特征
    （如红色标记区域、手写痕迹等）来生成合理的模拟结果。

    模拟策略：
    - 分析图像中红色/彩色区域的分布来推断批改标记
    - 基于图像区域特征分配不同的对错状态
    - 支持全对、有错、半对、未作答等多种场景
    """

    # 预定义的模拟题目模板（覆盖多个科目场景）
    MOCK_QUESTIONS = {
        "math": [
            {"num": 1, "text": "已知集合 A={1,2,3}, B={2,3,4}，求 A∩B", "max_score": 5},
            {"num": 2, "text": "求函数 f(x)=x^2-2x+3 在 [0,3] 上的最小值", "max_score": 5},
            {"num": 3, "text": "已知 sinα=3/5，α 为第二象限角，求 cosα", "max_score": 5},
            {"num": 4, "text": "求椭圆 x^2/9 + y^2/4 = 1 的离心率", "max_score": 5},
            {"num": 5, "text": "已知等差数列 {an} 中 a1=2, a5=10，求公差 d", "max_score": 5},
            {"num": 6, "text": "求曲线 y=x^3-3x 在点 (1,-2) 处的切线方程", "max_score": 8},
            {"num": 7, "text": "在△ABC中，已知 a=3, b=4, C=60°，求边 c", "max_score": 8},
            {"num": 8, "text": "已知向量 a=(2,1), b=(1,3)，求 a 与 b 的夹角", "max_score": 5},
            {"num": 9, "text": "证明：函数 f(x)=ln(x+1)-x/(x+1) 在 (0,+∞) 上单调递增", "max_score": 10},
            {"num": 10, "text": "从 5 名男生和 3 名女生中选 4 人参加比赛，求恰有 2 名女生的概率", "max_score": 8},
            {"num": 11, "text": "已知抛物线 y^2=4x 的焦点为 F，过 F 作倾斜角为 45° 的直线交抛物线于 A,B 两点，求 |AB|", "max_score": 12},
            {"num": 12, "text": "已知函数 f(x)=e^x-ax，讨论 f(x) 的单调性（其中 a 为参数）", "max_score": 12},
            {"num": 13, "text": "在正方体 ABCD-A1B1C1D1 中，求异面直线 A1B 与 B1C 所成角的大小", "max_score": 6},
            {"num": 14, "text": "已知随机变量 X 服从正态分布 N(2,σ^2)，P(X<4)=0.8，求 P(0<X<2)", "max_score": 6},
            {"num": 15, "text": "求数列 {n·2^n} 的前 n 项和", "max_score": 8},
            {"num": 16, "text": "已知双曲线 x^2/a^2 - y^2/b^2 = 1 的渐近线方程为 y=±(√3/3)x，求离心率", "max_score": 5},
            {"num": 17, "text": "利用导数证明：当 x>0 时，x - x^2/2 < ln(1+x) < x", "max_score": 8},
            {"num": 18, "text": "已知圆 C: x^2+y^2-4x+2y-4=0，求过点 P(1,2) 的圆的切线方程", "max_score": 8},
            {"num": 19, "text": "在△ABC中，若 sinA:sinB:sinC=3:5:7，判断三角形的形状", "max_score": 5},
            {"num": 20, "text": "已知函数 f(x)=x^3+ax^2+bx+c 在 x=1 处有极值 10，求 a,b,c 的值", "max_score": 10},
        ],
        "physics": [
            {"num": 1, "text": "一个物体从静止开始做匀加速直线运动，第3秒内的位移是5m，求加速度", "max_score": 6},
            {"num": 2, "text": "质量为 m 的物体在光滑斜面上由静止下滑，求加速度", "max_score": 6},
            {"num": 3, "text": "两个点电荷相距 r，电荷量分别为 Q 和 2Q，求连线中点场强", "max_score": 6},
            {"num": 4, "text": "一物体从高 h 处以初速度 v0 水平抛出，求落地时的速度大小", "max_score": 8},
            {"num": 5, "text": "在磁场 B 中，带电粒子 q 以速度 v 垂直射入，求轨道半径", "max_score": 6},
            {"num": 6, "text": "求卫星绕地球做匀速圆周运动的周期（已知轨道半径 r）", "max_score": 8},
            {"num": 7, "text": "一弹簧振子做简谐振动，振幅为 A，周期为 T，求最大速度", "max_score": 6},
            {"num": 8, "text": "已知理想气体在等温过程中体积从 V1 变为 V2，求做功", "max_score": 8},
            {"num": 9, "text": "两球发生完全非弹性碰撞，求碰撞后的共同速度", "max_score": 6},
            {"num": 10, "text": "一个物体在倾角为 θ 的斜面上匀速下滑，求动摩擦因数", "max_score": 6},
        ],
        "chemistry": [
            {"num": 1, "text": "写出铁与稀硫酸反应的化学方程式", "max_score": 4},
            {"num": 2, "text": "配平反应：KMnO4 + HCl → KCl + MnCl2 + Cl2 + H2O", "max_score": 6},
            {"num": 3, "text": "判断 Na2CO3 溶液的酸碱性并解释原因", "max_score": 6},
            {"num": 4, "text": "已知反应 N2 + 3H2 ⇌ 2NH3，增大压强平衡如何移动", "max_score": 4},
            {"num": 5, "text": "求 0.1mol/L HAc 溶液的 pH 值（Ka=1.8×10^-5）", "max_score": 8},
            {"num": 6, "text": "写出乙醇在浓硫酸催化下加热到 170°C 的反应方程式", "max_score": 4},
            {"num": 7, "text": "用电子式表示 NaCl 的形成过程", "max_score": 6},
            {"num": 8, "text": "判断 CH4、NH3、H2O 的键角大小并解释原因", "max_score": 6},
            {"num": 9, "text": "已知 Zn-Cu 原电池，写出正负极反应及总反应", "max_score": 8},
            {"num": 10, "text": "如何用化学方法鉴别 Na2CO3 和 NaHCO3", "max_score": 6},
        ],
        "chinese": [
            {"num": 1, "text": "下列词语中加点字的读音完全正确的一项是", "max_score": 3},
            {"num": 2, "text": "下列句子中，没有语病的一项是", "max_score": 3},
            {"num": 3, "text": "下列各句中，加点成语使用恰当的一项是", "max_score": 3},
            {"num": 4, "text": "阅读下面的文言文，解释加点词语的意思", "max_score": 8},
            {"num": 5, "text": "把文中画横线的句子翻译成现代汉语", "max_score": 10},
            {"num": 6, "text": "这首诗描绘了怎样的画面？表达了诗人什么情感", "max_score": 6},
            {"num": 7, "text": "赏析诗中“大漠孤烟直，长河落日圆”的艺术手法", "max_score": 6},
            {"num": 8, "text": "阅读下面的论述类文本，概括文章的主要观点", "max_score": 6},
            {"num": 9, "text": "分析小说中主人公的形象特点", "max_score": 8},
            {"num": 10, "text": "在下面一段文字横线处补写恰当的语句", "max_score": 6},
            {"num": 11, "text": "作文：以“坚持”为话题，写一篇不少于800字的议论文", "max_score": 60},
        ],
        "english": [
            {"num": 1, "text": "Choose the best answer: She ___ to school by bus every day.", "max_score": 2},
            {"num": 2, "text": "Fill in the blank: The book ___ (write) by Lu Xun is very popular.", "max_score": 2},
            {"num": 3, "text": "Reading Comprehension: What is the main idea of Paragraph 2?", "max_score": 4},
            {"num": 4, "text": "Cloze test: The old man looked ___ at his grandson with pride.", "max_score": 2},
            {"num": 5, "text": "Grammar: If I ___ (be) you, I would study harder.", "max_score": 2},
            {"num": 6, "text": "Error correction: She don't like playing basketball.", "max_score": 2},
            {"num": 7, "text": "Complete the sentence: Not until he arrived ___ (他才意识到) the meeting had been cancelled.", "max_score": 4},
            {"num": 8, "text": "Reading: Which of the following is TRUE according to the passage?", "max_score": 4},
            {"num": 9, "text": "Translation: 只有通过努力，我们才能实现梦想。", "max_score": 4},
            {"num": 10, "text": "Writing: Write a letter to your friend about your study plan. (100 words)", "max_score": 25},
        ],
    }

    def __init__(self):
        self.preprocessor = ImagePreprocessor()

    def analyze_paper(self, image: Image.Image) -> List[Dict[str, Any]]:
        """
        分析试卷，返回每道题的对错状态

        模拟策略：
        1. 分析图像特征（红色区域、密度分布等）
        2. 基于特征推断题目数量和科目
        3. 生成合理的对错状态分布

        Args:
            image: PIL Image 对象

        Returns:
            [
                {
                    "question_num": 1,
                    "text": "已知函数 f(x)=x^2+2x+1...",
                    "status": "correct" | "wrong" | "half" | "unanswered",
                    "max_score": 5,
                    "actual_score": 5,
                    "confidence": 0.95,
                },
                ...
            ]
        """
        # 1. 图像预处理
        processed = self.preprocessor.preprocess(image)

        # 2. 分析图像特征
        features = self._extract_features(image)

        # 3. 基于特征确定模拟参数
        subject = self._infer_subject(features)
        difficulty = self._infer_difficulty(features)
        question_count = self._estimate_question_count(image)

        # 4. 生成模拟结果
        return self._generate_mock_results(subject, question_count, difficulty, features)

    def _extract_features(self, image: Image.Image) -> Dict[str, Any]:
        """
        提取图像特征，用于推断试卷属性

        分析：
        - 红色区域比例（批改标记）
        - 图像整体亮度/对比度
        - 区域密度分布
        """
        img_array = np.array(image.convert("RGB"), dtype=np.float32)
        h, w, _ = img_array.shape

        # 红色区域检测（批改标记通常为红色）
        r, g, b = img_array[:, :, 0], img_array[:, :, 1], img_array[:, :, 2]
        # 红色判定：R 通道显著高于 G 和 B
        red_mask = (r > g * 1.3) & (r > b * 1.3) & (r > 100)
        red_ratio = float(red_mask.sum()) / (h * w)

        # 亮度分析
        gray = np.array(image.convert("L"), dtype=np.float32)
        mean_brightness = float(gray.mean())
        std_brightness = float(gray.std())

        # 图像复杂度（基于梯度）
        gy, gx = np.gradient(gray)
        gradient_magnitude = np.sqrt(gx**2 + gy**2)
        complexity = float(gradient_magnitude.mean())

        # 文字区域密度估计（简化版）
        # 按行扫描，检测文字行的密度
        row_density = []
        for row in range(0, h, max(1, h // 30)):
            row_data = gray[row:row + max(1, h // 30), :]
            # 文字区域通常有较高的局部方差
            row_var = float(np.var(row_data))
            row_density.append(row_var)

        # 估算文字区域占比
        text_region_ratio = sum(1 for v in row_density if v > np.median(row_density)) / max(len(row_density), 1)

        return {
            "red_ratio": red_ratio,
            "mean_brightness": mean_brightness,
            "std_brightness": std_brightness,
            "complexity": complexity,
            "text_region_ratio": text_region_ratio,
            "image_size": (w, h),
            "aspect_ratio": w / max(h, 1),
        }

    def _infer_subject(self, features: Dict[str, Any]) -> str:
        """
        基于图像特征推断科目

        简化策略：基于图像宽高比和复杂度推测
        - 数学/物理试卷通常包含更多公式和图形
        - 语文试卷文字密度更高
        """
        aspect = features["aspect_ratio"]
        complexity = features["complexity"]
        text_ratio = features["text_region_ratio"]

        # A4 纸比例约为 0.707 (210/297)
        # 试卷通常接近这个比例

        # 使用特征组合推断
        if complexity > 30 and text_ratio > 0.6:
            return "chinese"
        elif complexity > 25:
            return "math"
        elif text_ratio > 0.5:
            return "english"
        else:
            # 默认数学（最常见的试卷分析场景）
            return "math"

    def _infer_difficulty(self, features: Dict[str, Any]) -> str:
        """基于红色区域比例推断试卷难度（即错题比例）"""
        red_ratio = features["red_ratio"]

        if red_ratio < 0.005:
            return "easy"      # 几乎没有红色标记 → 全对
        elif red_ratio < 0.02:
            return "medium"    # 少量红色标记 → 少量错题
        elif red_ratio < 0.05:
            return "hard"      # 较多红色标记 → 较多错题
        else:
            return "very_hard" # 大量红色标记 → 大量错题

    def _estimate_question_count(self, image: Image.Image) -> int:
        """
        估算题目数量

        基于图像大小和文字密度粗略估算。
        实际 OCR 系统会通过版面分析精确确定题号。
        """
        h, w = image.size[1], image.size[0]
        area = h * w

        # 粗略估算：A4 纸大小的试卷通常有 15-20 道题
        # 根据面积和宽高比调整
        if area > 2000000:  # 大图
            return random.randint(16, 22)
        elif area > 1000000:
            return random.randint(10, 16)
        else:
            return random.randint(5, 10)

    def _generate_mock_results(
        self,
        subject: str,
        question_count: int,
        difficulty: str,
        features: Dict[str, Any],
    ) -> List[Dict[str, Any]]:
        """
        生成模拟的 OCR 识别结果

        基于图像特征和预设模板生成合理的对错分布。
        """
        # 获取对应科目的题目模板
        question_pool = self.MOCK_QUESTIONS.get(subject, self.MOCK_QUESTIONS["math"])

        # 根据题目数量选择题目
        if question_count <= len(question_pool):
            selected = random.sample(question_pool, question_count)
            # 按题号排序
            selected.sort(key=lambda x: x["num"])
        else:
            # 题目不够时循环使用
            selected = []
            pool = sorted(question_pool, key=lambda x: x["num"])
            for i in range(question_count):
                q = pool[i % len(pool)].copy()
                q["num"] = i + 1
                selected.append(q)

        # 根据难度决定对错分布
        status_weights = self._get_status_weights(difficulty)

        results = []
        for q in selected:
            # 基于权重随机选择对错状态
            status = random.choices(
                list(status_weights.keys()),
                weights=list(status_weights.values()),
                k=1,
            )[0]

            max_score = q["max_score"]
            actual_score = self._calculate_actual_score(status, max_score)

            # 置信度：模拟 OCR 的识别置信度
            confidence = self._generate_confidence(status, features)

            results.append({
                "question_num": q["num"],
                "text": q["text"],
                "status": status,
                "max_score": max_score,
                "actual_score": actual_score,
                "confidence": confidence,
            })

        return results

    def _get_status_weights(self, difficulty: str) -> Dict[str, float]:
        """根据难度获取各状态的概率权重"""
        weights = {
            "easy": {"correct": 0.75, "wrong": 0.10, "half": 0.08, "unanswered": 0.07},
            "medium": {"correct": 0.50, "wrong": 0.25, "half": 0.15, "unanswered": 0.10},
            "hard": {"correct": 0.25, "wrong": 0.40, "half": 0.20, "unanswered": 0.15},
            "very_hard": {"correct": 0.10, "wrong": 0.50, "half": 0.20, "unanswered": 0.20},
        }
        return weights.get(difficulty, weights["medium"])

    def _calculate_actual_score(self, status: str, max_score: float) -> float:
        """根据对错状态计算实际得分"""
        if status == "correct":
            return max_score
        elif status == "wrong":
            return 0.0
        elif status == "half":
            return round(max_score * random.uniform(0.3, 0.7), 1)
        elif status == "unanswered":
            return 0.0
        return 0.0

    def _generate_confidence(self, status: str, features: Dict[str, Any]) -> float:
        """
        生成模拟的 OCR 置信度

        置信度受图像质量影响：
        - 清晰图像置信度高
        - 模糊/噪点多置信度低
        - 正确/错误的标记比半对/未作答更易识别
        """
        # 基于图像质量的基础置信度
        brightness = features["mean_brightness"]
        complexity = features["complexity"]

        # 亮度适中的图像质量好
        brightness_score = 1.0 - abs(brightness - 128) / 128

        # 复杂度适中的图像更清晰
        complexity_score = 1.0 - min(complexity / 80, 0.5)

        base_confidence = (brightness_score + complexity_score) / 2
        base_confidence = max(0.6, min(base_confidence, 0.98))

        # 不同状态的置信度调整
        status_adjust = {
            "correct": 0.03,
            "wrong": 0.03,
            "half": -0.08,
            "unanswered": -0.05,
        }

        confidence = base_confidence + status_adjust.get(status, 0)
        confidence += random.uniform(-0.03, 0.03)  # 添加随机噪声

        return round(max(0.5, min(confidence, 0.99)), 4)

    def batch_analyze(self, images: List[Image.Image]) -> List[List[Dict[str, Any]]]:
        """批量分析多页试卷"""
        return [self.analyze_paper(img) for img in images]
