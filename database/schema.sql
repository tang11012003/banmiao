-- ============================================================================
-- 陪读社区 App - PostgreSQL 数据库建表语句
-- Version: 1.0.0
-- 
-- Neo4j 知识图谱设计说明见文件末尾
-- ============================================================================

-- ============================================================================
-- 1. 用户与认证模块
-- ============================================================================

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id              BIGSERIAL PRIMARY KEY,
    phone           VARCHAR(20) NOT NULL UNIQUE,
    nickname        VARCHAR(50) DEFAULT '',
    avatar          VARCHAR(500) DEFAULT '',
    role            VARCHAR(20) NOT NULL DEFAULT 'unverified'
                    CHECK (role IN ('unverified', 'parent', 'admin', 'banned')),
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'banned')),
    password_hash   VARCHAR(255) DEFAULT '', -- 预留密码登录
    verified_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users (phone);
CREATE INDEX idx_users_role ON users (role);
CREATE INDEX idx_users_status ON users (status);

-- 认证审核表
CREATE TABLE IF NOT EXISTS auth_verifications (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    method          VARCHAR(20) NOT NULL
                    CHECK (method IN ('student_card', 'class_group', 'payment', 'invite_code')),
    material_image  VARCHAR(500) DEFAULT '',       -- 认证材料图片 URL
    invite_code     VARCHAR(20) DEFAULT '',         -- 使用的邀请码
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewer_id     BIGINT REFERENCES users(id),   -- 审核人 ID
    review_note     TEXT DEFAULT '',
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auth_verifications_user_id ON auth_verifications (user_id);
CREATE INDEX idx_auth_verifications_status ON auth_verifications (status);
CREATE INDEX idx_auth_verifications_created_at ON auth_verifications (created_at);

-- 邀请码表
CREATE TABLE IF NOT EXISTS invite_codes (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(20) NOT NULL UNIQUE,
    inviter_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    max_uses        INT NOT NULL DEFAULT 3,        -- 最大使用次数
    used_count      INT NOT NULL DEFAULT 0,
    expires_at      TIMESTAMPTZ NOT NULL,           -- 30 天有效期
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invite_codes_code ON invite_codes (code);
CREATE INDEX idx_invite_codes_inviter_id ON invite_codes (inviter_id);

-- ============================================================================
-- 2. 学生信息模块
-- ============================================================================

-- 学生（孩子）信息表
CREATE TABLE IF NOT EXISTS students (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(50) NOT NULL DEFAULT '',
    province        VARCHAR(50) DEFAULT '',
    city            VARCHAR(50) DEFAULT '',
    school          VARCHAR(100) DEFAULT '',
    grade           VARCHAR(10) DEFAULT '高三'
                    CHECK (grade IN ('高一', '高二', '高三')),
    subjects        TEXT[] DEFAULT '{}',            -- 选科数组，如 {"物理","化学","生物"}
    exam_type       VARCHAR(20) DEFAULT '全国卷'
                    CHECK (exam_type IN ('全国卷', '新高考', '自主命题')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_students_user_id ON students (user_id);
CREATE INDEX idx_students_grade ON students (grade);
CREATE INDEX idx_students_province ON students (province);

-- ============================================================================
-- 3. 考试与试卷模块
-- ============================================================================

-- 考试记录表
CREATE TABLE IF NOT EXISTS exams (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    student_id      BIGINT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,          -- 考试名称：一模、二模、校月考
    subject         VARCHAR(20) NOT NULL,           -- 科目
    exam_date       DATE NOT NULL,
    total_score     DECIMAL(6,1) DEFAULT 0,        -- 总分
    scored_rate     DECIMAL(5,2) DEFAULT 0,        -- 得分率 0-100
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_exams_user_id ON exams (user_id);
CREATE INDEX idx_exams_student_id ON exams (student_id);
CREATE INDEX idx_exams_exam_date ON exams (exam_date);
CREATE INDEX idx_exams_subject ON exams (subject);

-- 试卷表（一次上传对应一张试卷）
CREATE TABLE IF NOT EXISTS papers (
    id              BIGSERIAL PRIMARY KEY,
    exam_id         BIGINT NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pages           INT NOT NULL DEFAULT 1,         -- 页数
    ocr_status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (ocr_status IN ('pending', 'processing', 'completed', 'failed')),
    ocr_error       TEXT DEFAULT '',                -- OCR 错误信息
    ocr_started_at  TIMESTAMPTZ,
    ocr_completed_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_papers_exam_id ON papers (exam_id);
CREATE INDEX idx_papers_ocr_status ON papers (ocr_status);
CREATE INDEX idx_papers_user_id ON papers (user_id);

-- 试卷题目明细表（每道题）
CREATE TABLE IF NOT EXISTS paper_items (
    id              BIGSERIAL PRIMARY KEY,
    paper_id        BIGINT NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    question_num    INT NOT NULL,                   -- 题号
    text            TEXT DEFAULT '',                -- OCR 识别出的题目文本
    status          VARCHAR(20) NOT NULL DEFAULT 'unanswered'
                    CHECK (status IN ('correct', 'wrong', 'half', 'unanswered')),
    max_score       DECIMAL(5,1) DEFAULT 0,
    actual_score    DECIMAL(5,1) DEFAULT 0,
    image_url       VARCHAR(500) DEFAULT '',        -- 题目截图 URL
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_paper_items_paper_id ON paper_items (paper_id);
CREATE INDEX idx_paper_items_status ON paper_items (status);

-- ============================================================================
-- 4. 知识图谱模块（PostgreSQL 端）
-- ============================================================================

-- 知识点表（PostgreSQL 中的关系型镜像，Neo4j 为主存储）
CREATE TABLE IF NOT EXISTS knowledge_points (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,          -- 知识点名称
    subject         VARCHAR(20) NOT NULL,           -- 所属科目
    chapter         VARCHAR(200) DEFAULT '',        -- 章节名称
    section         VARCHAR(200) DEFAULT '',        -- 小节名称
    parent_id       BIGINT REFERENCES knowledge_points(id), -- 父知识点
    level           INT NOT NULL DEFAULT 3,         -- 层级：1=科目 2=章节 3=知识点
    neo4j_id        VARCHAR(50) DEFAULT '',         -- Neo4j 中对应节点 ID
    description     TEXT DEFAULT '',                -- 知识点描述
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_knowledge_points_subject ON knowledge_points (subject);
CREATE INDEX idx_knowledge_points_parent_id ON knowledge_points (parent_id);
CREATE INDEX idx_knowledge_points_level ON knowledge_points (level);

-- 考试-知识点分析结果表
CREATE TABLE IF NOT EXISTS exam_kp_results (
    id                  BIGSERIAL PRIMARY KEY,
    exam_id             BIGINT NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    knowledge_point_id  BIGINT NOT NULL REFERENCES knowledge_points(id) ON DELETE CASCADE,
    total_questions     INT NOT NULL DEFAULT 0,     -- 该知识点下总题数
    wrong_questions     INT NOT NULL DEFAULT 0,     -- 错题数
    error_rate          DECIMAL(5,4) DEFAULT 0,     -- 错误率 0-1
    level               VARCHAR(20) NOT NULL DEFAULT 'keep'
                        CHECK (level IN ('urgent', 'attention', 'keep')),
    -- urgent: 待改进（错误率 >= 50%）
    -- attention: 需关注（20% <= 错误率 < 50%）
    -- keep: 继续保持（错误率 < 20%）
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_exam_kp_results_exam_id ON exam_kp_results (exam_id);
CREATE INDEX idx_exam_kp_results_kp_id ON exam_kp_results (knowledge_point_id);
CREATE INDEX idx_exam_kp_results_level ON exam_kp_results (level);

-- ============================================================================
-- 5. 社区模块
-- ============================================================================

-- 圈子表
CREATE TABLE IF NOT EXISTS community_circles (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    category        VARCHAR(20) NOT NULL
                    CHECK (category IN ('grade', 'region', 'subject', 'topic')),
    description     TEXT DEFAULT '',
    icon            VARCHAR(500) DEFAULT '',
    post_count      INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_circles_category ON community_circles (category);

-- 社区帖子表
CREATE TABLE IF NOT EXISTS community_posts (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    circle_id       BIGINT NOT NULL REFERENCES community_circles(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL DEFAULT '',
    content         TEXT NOT NULL,
    content_type    VARCHAR(20) NOT NULL DEFAULT 'text'
                    CHECK (content_type IN ('text', 'qa', 'share_report')),
    images          TEXT[] DEFAULT '{}',             -- 图片 URL 数组，最多 9 张
    status          VARCHAR(20) NOT NULL DEFAULT 'pending_review'
                    CHECK (status IN ('pending_review', 'published', 'rejected')),
    review_note     TEXT DEFAULT '',
    reviewer_id     BIGINT REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    like_count      INT NOT NULL DEFAULT 0,
    comment_count   INT NOT NULL DEFAULT 0,
    share_count     INT NOT NULL DEFAULT 0,
    view_count      INT NOT NULL DEFAULT 0,
    is_pinned       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_posts_user_id ON community_posts (user_id);
CREATE INDEX idx_community_posts_circle_id ON community_posts (circle_id);
CREATE INDEX idx_community_posts_status ON community_posts (status);
CREATE INDEX idx_community_posts_created_at ON community_posts (created_at);
CREATE INDEX idx_community_posts_content_type ON community_posts (content_type);

-- 社区评论表
CREATE TABLE IF NOT EXISTS community_comments (
    id              BIGSERIAL PRIMARY KEY,
    post_id         BIGINT NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id       BIGINT REFERENCES community_comments(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    like_count      INT NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'published'
                    CHECK (status IN ('published', 'hidden', 'deleted')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_comments_post_id ON community_comments (post_id);
CREATE INDEX idx_community_comments_user_id ON community_comments (user_id);
CREATE INDEX idx_community_comments_parent_id ON community_comments (parent_id);

-- 点赞记录表
CREATE TABLE IF NOT EXISTS community_likes (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type     VARCHAR(20) NOT NULL CHECK (target_type IN ('post', 'comment')),
    target_id       BIGINT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, target_type, target_id)       -- 防止重复点赞
);

CREATE INDEX idx_community_likes_target ON community_likes (target_type, target_id);

-- ============================================================================
-- 6. 分享与配额模块
-- ============================================================================

-- 分享记录表
CREATE TABLE IF NOT EXISTS share_records (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    report_id       BIGINT NOT NULL,               -- 关联的分析报告（exam 或 paper）
    report_type     VARCHAR(20) NOT NULL DEFAULT 'exam'
                    CHECK (report_type IN ('exam', 'paper')),
    channel         VARCHAR(20) NOT NULL
                    CHECK (channel IN ('wechat', 'moments', 'group', 'copy_link')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_share_records_user_id ON share_records (user_id);
CREATE INDEX idx_share_records_created_at ON share_records (created_at);
-- 同一报告 24 小时内同渠道分享仅首次计入
CREATE INDEX idx_share_records_dedup ON share_records (user_id, report_id, channel, created_at);

-- 分析次数配额表
CREATE TABLE IF NOT EXISTS analysis_quotas (
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    year_month      VARCHAR(7) NOT NULL,            -- 格式: 2025-07
    free_quota      INT NOT NULL DEFAULT 3,          -- 每月免费 3 次
    free_used       INT NOT NULL DEFAULT 0,
    bonus_quota     INT NOT NULL DEFAULT 0,          -- 分享获取的额外次数
    bonus_used      INT NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, year_month)
);

CREATE INDEX idx_analysis_quotas_user_id ON analysis_quotas (user_id);

-- ============================================================================
-- 7. 通知模块
-- ============================================================================

-- 通知表
CREATE TABLE IF NOT EXISTS notifications (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            VARCHAR(30) NOT NULL
                    CHECK (type IN (
                        'auth_approved', 'auth_rejected',
                        'exam_reminder', 'upload_reminder',
                        'post_reviewed', 'post_rejected',
                        'comment_reply', 'new_answer',
                        'quota_low', 'system'
                    )),
    title           VARCHAR(200) NOT NULL,
    content         TEXT DEFAULT '',
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    related_id      BIGINT DEFAULT 0,              -- 关联的业务 ID
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications (user_id);
CREATE INDEX idx_notifications_is_read ON notifications (user_id, is_read);
CREATE INDEX idx_notifications_created_at ON notifications (created_at);

-- ============================================================================
-- 8. 考试日历模块
-- ============================================================================

-- 考试日历事件表
CREATE TABLE IF NOT EXISTS calendar_events (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    student_id      BIGINT REFERENCES students(id) ON DELETE SET NULL,
    title           VARCHAR(200) NOT NULL,
    event_type      VARCHAR(20) NOT NULL DEFAULT 'custom'
                    CHECK (event_type IN (
                        'mock_exam', 'gaokao', 'physical_exam',
                        'oral_exam', 'registration', 'volunteer',
                        'custom'
                    )),
    event_date      DATE NOT NULL,
    subject         VARCHAR(20) DEFAULT '',         -- 考试科目（多科用逗号分隔）
    reminder_before INT DEFAULT 0,                  -- 提前多少天提醒
    is_reminded     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_calendar_events_user_id ON calendar_events (user_id);
CREATE INDEX idx_calendar_events_event_date ON calendar_events (event_date);
CREATE INDEX idx_calendar_events_event_type ON calendar_events (event_type);

-- ============================================================================
-- 9. 默认数据
-- ============================================================================

-- 预置圈子
INSERT INTO community_circles (name, category, description) VALUES
    ('高三陪读圈', 'grade', '高三家长交流陪读经验'),
    ('高一高二预备圈', 'grade', '高一高二家长提前准备'),
    ('广东陪读圈', 'region', '广东地区陪读家长交流'),
    ('北京陪读圈', 'region', '北京地区陪读家长交流'),
    ('数学交流圈', 'subject', '数学其它与经验分享'),
    ('语文交流圈', 'subject', '语文其它与经验分享'),
    ('英语交流圈', 'subject', '英语其它与经验分享'),
    ('营养食谱', 'topic', '陪读期间营养餐分享'),
    ('心理调适', 'topic', '考前心理调节与压力管理'),
    ('志愿填报', 'topic', '高考志愿填报经验交流'),
    ('政策解读', 'topic', '高考政策解读与讨论')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- Neo4j 知识图谱设计说明
-- ============================================================================
--
-- 知识图谱是陪读社区的核心数据架构，用于存储高考各科知识点的层级关系，
-- 并支持基于语义向量的知识点匹配。
--
-- ## 节点类型
--
-- ### 1. Subject（科目节点）
-- ```
-- (:Subject {
--     id: "math",
--     name: "数学",
--     level: 1
-- })
-- ```
--
-- ### 2. Chapter（章节节点）
-- ```
-- (:Chapter {
--     id: "math_func_derivative",
--     name: "函数与导数",
--     subject: "math",
--     level: 2
-- })
-- ```
--
-- ### 3. Section（小节节点）
-- ```
-- (:Section {
--     id: "math_func_basic",
--     name: "函数的概念与性质",
--     chapter: "math_func_derivative",
--     subject: "math",
--     level: 2
-- })
-- ```
--
-- ### 4. KnowledgePoint（知识点节点）
-- ```
-- (:KnowledgePoint {
--     id: "kp_domain_range",
--     name: "定义域与值域",
--     subject: "math",
--     chapter: "math_func_derivative",
--     section: "math_func_basic",
--     level: 3,
--     description: "函数的定义域和值域的求解方法",
--     vector_embedding: [0.12, -0.34, ...]  // 语义向量（768维）
-- })
-- ```
--
-- ## 关系类型
--
-- - `(:Subject)-[:HAS_CHAPTER]->(:Chapter)` — 科目包含章节
-- - `(:Chapter)-[:HAS_SECTION]->(:Section)` — 章节包含小节
-- - `(:Section)-[:HAS_KNOWLEDGE_POINT]->(:KnowledgePoint)` — 小节包含知识点
-- - `(:KnowledgePoint)-[:PREREQUISITE]->(:KnowledgePoint)` — 前置知识点关系
-- - `(:KnowledgePoint)-[:RELATED_TO {weight: 0.8}]->(:KnowledgePoint)` — 相关知识点（带权重）
--
-- ## 示例 Cypher 语句
--
-- 创建数学知识点层级：
-- ```cypher
-- CREATE (math:Subject {id: "math", name: "数学", level: 1})
-- CREATE (func:Chapter {id: "math_func", name: "函数与导数", subject: "math", level: 2})
-- CREATE (basic:Section {id: "math_func_basic", name: "函数的概念与性质", chapter: "math_func", subject: "math", level: 2})
-- CREATE (domain:KnowledgePoint {
--     id: "kp_domain_range",
--     name: "定义域与值域",
--     subject: "math",
--     chapter: "math_func",
--     section: "math_func_basic",
--     level: 3,
--     description: "函数的定义域和值域的求解方法"
-- })
-- CREATE (math)-[:HAS_CHAPTER]->(func)
-- CREATE (func)-[:HAS_SECTION]->(basic)
-- CREATE (basic)-[:HAS_KNOWLEDGE_POINT]->(domain)
-- ```
--
-- ## 语义匹配流程
--
-- 1. 错题文本通过 sentence-transformers 编码为 768 维向量
-- 2. 在 Neo4j 中使用向量索引检索最相似的 KnowledgePoint 节点
-- 3. 返回 Top 3 匹配结果及相似度分数
-- 4. 若最高相似度 < 0.7，标记为"未匹配"进入人工复核队列
