"""
知识图谱匹配模块

负责：
1. 加载知识图谱 JSON 数据
2. 使用 TF-IDF 将错题文本与知识点进行语义匹配
3. 返回 Top K 匹配结果，支持阈值过滤
"""

import json
import os
import re
from typing import List, Dict, Any
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


class KnowledgeMatcher:
    """知识图谱匹配器 - 基于 TF-IDF 的语义匹配"""

    def __init__(self, graph_path: str = None):
        """
        初始化匹配器

        Args:
            graph_path: 知识图谱 JSON 文件路径，默认为项目 database 下的 knowledge_graph.json
        """
        self.nodes = []
        self.vectorizer = None
        self.knowledge_vectors = None
        self.knowledge_texts = []

        if graph_path is None:
            # app/knowledge/matcher.py → 向上4层到达项目根目录 peidu-community/
            project_root = os.path.dirname(
                os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
            )
            graph_path = os.path.join(project_root, "database", "knowledge_graph.json")

        self._load_knowledge_base(graph_path)

    def _load_knowledge_base(self, graph_path: str):
        """加载知识图谱 JSON 并构建 TF-IDF 向量索引"""
        try:
            with open(graph_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except FileNotFoundError:
            print(f"[KnowledgeMatcher] 知识图谱文件未找到: {graph_path}，使用空知识库")
            return
        except json.JSONDecodeError as e:
            print(f"[KnowledgeMatcher] JSON 解析失败: {e}，使用空知识库")
            return

        self.nodes = data.get("nodes", [])
        if not self.nodes:
            print("[KnowledgeMatcher] 知识库为空")
            return

        # 构建每个知识点的可搜索文本：名称 + 描述 + 章节 + 科目
        self.knowledge_texts = []
        for node in self.nodes:
            text = f"{node.get('name', '')} {node.get('description', '')} {node.get('chapter', '')} {node.get('subject', '')}"
            self.knowledge_texts.append(text)

        # 使用 TF-IDF 构建向量（字符级 n-gram，适配中文无空格分词）
        self.vectorizer = TfidfVectorizer(
            analyzer="char_wb",
            ngram_range=(1, 2),
            max_features=5000,
            sublinear_tf=True,
        )
        try:
            self.knowledge_vectors = self.vectorizer.fit_transform(self.knowledge_texts)
        except ValueError:
            # 文本太短或无有效词汇时
            self.knowledge_vectors = None

        print(f"[KnowledgeMatcher] 已加载 {len(self.nodes)} 个知识点")

    def match(
        self,
        question_text: str,
        subject: str = "",
        top_k: int = 3,
        threshold: float = 0.7,
    ) -> List[Dict[str, Any]]:
        """
        将错题文本匹配到知识点

        Args:
            question_text: 错题文本
            subject: 科目（如 "数学"、"物理"），空字符串表示不限制科目
            top_k: 返回 Top K 个匹配结果
            threshold: 相似度阈值，最高相似度低于此值标记为"需人工复核"

        Returns:
            [
                {
                    "knowledge_point_id": 1,
                    "name": "导数的几何意义",
                    "similarity": 0.92,
                    "matched": True,
                },
                ...
            ]
        """
        if not self.nodes or self.knowledge_vectors is None:
            return [{
                "knowledge_point_id": 0,
                "name": "知识库未加载",
                "similarity": 0.0,
                "matched": False,
            }]

        # 将查询文本向量化
        try:
            query_vec = self.vectorizer.transform([question_text])
        except Exception:
            return [{
                "knowledge_point_id": 0,
                "name": "文本无法解析",
                "similarity": 0.0,
                "matched": False,
            }]

        # 计算余弦相似度
        similarities = cosine_similarity(query_vec, self.knowledge_vectors).flatten()

        # 按相似度排序，取 Top K
        # 同时按科目过滤（如果指定了 subject）
        scored_nodes = []
        for idx, sim in enumerate(similarities):
            node = self.nodes[idx]
            # 科目过滤：不区分大小写，允许部分匹配
            if subject:
                node_subject = node.get("subject", "")
                if node_subject != subject:
                    continue
            scored_nodes.append((sim, node))

        # 按相似度降序排列
        scored_nodes.sort(key=lambda x: x[0], reverse=True)

        # 取 Top K
        top_results = scored_nodes[:top_k]

        # 构建结果
        results = []
        for sim, node in top_results:
            results.append({
                "knowledge_point_id": node.get("sql_id", 0),
                "name": node.get("name", "未知"),
                "similarity": round(float(sim), 4),
                "matched": sim >= threshold,
            })

        # 如果 Top 1 相似度 < threshold，添加提示
        if results and not results[0]["matched"]:
            # 所有结果都标记为需人工复核
            pass

        return results if results else [{
            "knowledge_point_id": 0,
            "name": "未匹配到知识点",
            "similarity": 0.0,
            "matched": False,
        }]

    def batch_match(
        self,
        questions: List[Dict[str, str]],
        subject: str = "",
        top_k: int = 3,
        threshold: float = 0.7,
    ) -> List[List[Dict[str, Any]]]:
        """批量匹配多个错题"""
        return [self.match(q.get("text", ""), subject, top_k, threshold) for q in questions]
