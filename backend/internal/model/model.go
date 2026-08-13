package model

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"
)

// StringSlice 以 JSON 文本形式存储字符串数组，兼容 PostgreSQL，避免依赖数组驱动。
// 既实现了 driver.Valuer / sql.Scanner，又能在 JSON 序列化时直接输出数组。
type StringSlice []string

// Value 实现 driver.Valuer
func (s StringSlice) Value() (driver.Value, error) {
	if s == nil {
		return "[]", nil
	}
	b, err := json.Marshal(s)
	if err != nil {
		return nil, err
	}
	return string(b), nil
}

// Scan 实现 sql.Scanner
func (s *StringSlice) Scan(v interface{}) error {
	if v == nil {
		*s = StringSlice{}
		return nil
	}
	var data []byte
	switch val := v.(type) {
	case []byte:
		data = val
	case string:
		data = []byte(val)
	default:
		return errors.New("unsupported type for StringSlice")
	}
	if len(data) == 0 {
		*s = StringSlice{}
		return nil
	}
	return json.Unmarshal(data, s)
}

// MarshalJSON 保证 API 输出为数组
func (s StringSlice) MarshalJSON() ([]byte, error) {
	if s == nil {
		return []byte("[]"), nil
	}
	return json.Marshal([]string(s))
}

// User 用户模型
type User struct {
	ID           int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	Phone        string    `json:"phone" gorm:"size:20;uniqueIndex;not null" db:"phone"`
	Nickname     string    `json:"nickname" gorm:"size:50" db:"nickname"`
	Avatar       string    `json:"avatar" gorm:"size:500" db:"avatar"`
	PasswordHash string    `json:"-" gorm:"size:255" db:"password_hash"`
	Role         string    `json:"role" gorm:"size:20;not null;default:unverified" db:"role"` // unverified, parent, admin, banned
	Status       string    `json:"status" gorm:"size:20;not null;default:active" db:"status"` // active, banned
	VerifiedAt   *time.Time `json:"verified_at" db:"verified_at"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

// TableName 指定表名
func (User) TableName() string { return "users" }

// Student 学生（孩子）信息
type Student struct {
	ID        int64      `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID    int64      `json:"user_id" gorm:"index;not null" db:"user_id"`
	Name      string     `json:"name" gorm:"size:50" db:"name"`
	Province  string     `json:"province" gorm:"size:50" db:"province"`
	City      string     `json:"city" gorm:"size:50" db:"city"`
	School    string     `json:"school" gorm:"size:100" db:"school"`
	Grade     string     `json:"grade" gorm:"size:10;default:高三" db:"grade"` // 高一, 高二, 高三
	Subjects  StringSlice `json:"subjects" gorm:"type:text" db:"subjects"`     // 选科，如 ["物理","化学","生物"]
	ExamType  string     `json:"exam_type" gorm:"size:20;default:全国卷" db:"exam_type"` // 全国卷, 新高考, 自主命题
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
}

func (Student) TableName() string { return "students" }

// CalendarEvent 高考日历事件
type CalendarEvent struct {
	ID             int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID         int64     `json:"user_id" gorm:"index;not null" db:"user_id"`
	StudentID      *int64    `json:"student_id" gorm:"index" db:"student_id"`
	Title          string    `json:"title" gorm:"size:200;not null" db:"title"`
	Event          string    `json:"event_type" gorm:"size:20;default:custom" db:"event_type"` // mock_exam, gaokao, physical_exam, oral_exam, registration, volunteer, custom
	EventDate      time.Time `json:"event_date" gorm:"not null" db:"event_date"`
	Subject        string    `json:"subject" gorm:"size:20" db:"subject"`
	ReminderBefore int       `json:"reminder_before" gorm:"default:0" db:"reminder_before"`
	IsReminded     bool      `json:"is_reminded" gorm:"not null;default:false" db:"is_reminded"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
}

func (CalendarEvent) TableName() string { return "calendar_events" }

// Exam 考试记录（模拟考/正式考的成绩记录）
type Exam struct {
	ID         int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID     int64     `json:"user_id" gorm:"index;not null" db:"user_id"`
	StudentID  int64     `json:"student_id" gorm:"index;not null" db:"student_id"`
	Name       string    `json:"name" gorm:"size:100;not null" db:"name"` // 一模, 二模, 校月考
	Subject    string    `json:"subject" gorm:"size:20;not null" db:"subject"`
	ExamDate   time.Time `json:"exam_date" gorm:"not null" db:"exam_date"`
	TotalScore float64   `json:"total_score" gorm:"type:decimal(6,1);default:0" db:"total_score"`
	ScoredRate float64   `json:"scored_rate" gorm:"type:decimal(5,2);default:0" db:"scored_rate"` // 得分率 0-100
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

func (Exam) TableName() string { return "exams" }

// Paper 试卷
type Paper struct {
	ID             int64      `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	ExamID         int64      `json:"exam_id" gorm:"index" db:"exam_id"`
	UserID         int64      `json:"user_id" gorm:"index;not null" db:"user_id"`
	Pages          int        `json:"pages" gorm:"not null;default:1" db:"pages"`
	ImageURL       string     `json:"image_url" gorm:"size:500" db:"image_url"`
	OCRStatus      string     `json:"ocr_status" gorm:"size:20;not null;default:pending" db:"ocr_status"` // pending, processing, scanned, completed, failed
	OCRError       string     `json:"ocr_error" gorm:"type:text" db:"ocr_error"`
	OCRStartedAt   *time.Time `json:"ocr_started_at" db:"ocr_started_at"`
	OCRCompletedAt *time.Time `json:"ocr_completed_at" db:"ocr_completed_at"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
}

func (Paper) TableName() string { return "papers" }

// PaperItem 试卷中的每道题
type PaperItem struct {
	ID          int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	PaperID     int64     `json:"paper_id" gorm:"index;not null" db:"paper_id"`
	QuestionNum int       `json:"question_num" gorm:"not null" db:"question_num"`
	Text        string    `json:"text" gorm:"type:text" db:"text"`     // OCR 识别出的题目文本
	Status      string    `json:"status" gorm:"size:20;default:unanswered" db:"status"` // correct, wrong, half, unanswered
	MaxScore    float64   `json:"max_score" gorm:"type:decimal(5,1);default:0" db:"max_score"`
	ActualScore float64   `json:"actual_score" gorm:"type:decimal(5,1);default:0" db:"actual_score"`
	ImageURL    string    `json:"image_url" gorm:"size:500" db:"image_url"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

func (PaperItem) TableName() string { return "paper_items" }

// KnowledgePoint 知识点
type KnowledgePoint struct {
	ID          int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	Name        string    `json:"name" gorm:"size:200;not null" db:"name"`
	Subject     string    `json:"subject" gorm:"size:20;not null;index" db:"subject"`
	Chapter     string    `json:"chapter" gorm:"size:200" db:"chapter"`  // 章节
	Section     string    `json:"section" gorm:"size:200" db:"section"`  // 小节
	ParentID    *int64    `json:"parent_id" gorm:"index" db:"parent_id"` // 父知识点（层级结构）
	Level       int       `json:"level" gorm:"default:3" db:"level"`     // 层级 1=科目 2=章节 3=知识点
	Neo4jID     string    `json:"neo4j_id" gorm:"size:50" db:"neo4j_id"` // Neo4j 中对应节点 ID
	Description string    `json:"description" gorm:"type:text" db:"description"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

func (KnowledgePoint) TableName() string { return "knowledge_points" }

// ExamKPResult 考试-知识点分析结果
type ExamKPResult struct {
	ID               int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	ExamID           int64     `json:"exam_id" gorm:"index;not null" db:"exam_id"`
	KnowledgePointID int64     `json:"knowledge_point_id" gorm:"index;not null" db:"knowledge_point_id"`
	KnowledgeName    string    `json:"knowledge_name" gorm:"size:200" db:"knowledge_name"`
	TotalQuestions   int       `json:"total_questions" gorm:"not null;default:0" db:"total_questions"`
	WrongQuestions   int       `json:"wrong_questions" gorm:"not null;default:0" db:"wrong_questions"`
	ErrorRate        float64   `json:"error_rate" gorm:"type:decimal(5,4);default:0" db:"error_rate"`
	Level            string    `json:"level" gorm:"size:20;not null;default:keep" db:"level"` // urgent(待改进), attention(需关注), keep(继续保持)
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
}

func (ExamKPResult) TableName() string { return "exam_kp_results" }

// CommunityCircle 圈子
type CommunityCircle struct {
	ID          int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	Name        string    `json:"name" gorm:"size:100;not null" db:"name"`
	Category    string    `json:"category" gorm:"size:20;not null" db:"category"` // grade, region, subject, topic
	Description string    `json:"description" gorm:"type:text" db:"description"`
	Icon        string    `json:"icon" gorm:"size:500" db:"icon"`
	PostCount   int       `json:"post_count" gorm:"not null;default:0" db:"post_count"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

func (CommunityCircle) TableName() string { return "community_circles" }

// CommunityPost 社区帖子
type CommunityPost struct {
	ID          int64      `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID      int64      `json:"user_id" gorm:"index;not null" db:"user_id"`
	CircleID    int64      `json:"circle_id" gorm:"index;not null" db:"circle_id"`
	Title       string     `json:"title" gorm:"size:200" db:"title"`
	Content     string     `json:"content" gorm:"type:text;not null" db:"content"`
	ContentType string     `json:"content_type" gorm:"size:20;not null;default:text" db:"content_type"` // text, qa, share_report
	Images      StringSlice `json:"images" gorm:"type:text" db:"images"`
	Status      string     `json:"status" gorm:"size:20;not null;default:pending_review" db:"status"` // pending_review, published, rejected
	ReviewNote  string     `json:"review_note" gorm:"type:text" db:"review_note"`
	ReviewerID  *int64     `json:"reviewer_id" db:"reviewer_id"`
	ReviewedAt  *time.Time `json:"reviewed_at" db:"reviewed_at"`
	LikeCount   int        `json:"like_count" gorm:"not null;default:0" db:"like_count"`
	CommentCount int       `json:"comment_count" gorm:"not null;default:0" db:"comment_count"`
	ShareCount  int        `json:"share_count" gorm:"not null;default:0" db:"share_count"`
	ViewCount   int        `json:"view_count" gorm:"not null;default:0" db:"view_count"`
	IsPinned    bool       `json:"is_pinned" gorm:"not null;default:false" db:"is_pinned"`
	ReportRefID int64      `json:"report_ref_id" gorm:"index" db:"report_ref_id"` // 关联分析报告(exam_id)，用于 share_report
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

func (CommunityPost) TableName() string { return "community_posts" }

// CommunityComment 社区评论
type CommunityComment struct {
	ID        int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	PostID    int64     `json:"post_id" gorm:"index;not null" db:"post_id"`
	UserID    int64     `json:"user_id" gorm:"index;not null" db:"user_id"`
	ParentID  *int64    `json:"parent_id" gorm:"index" db:"parent_id"` // 父评论 ID（支持嵌套）
	Content   string    `json:"content" gorm:"type:text;not null" db:"content"`
	Image     string    `json:"image" gorm:"size:500" db:"image"` // 评论图片（开发态 URL）
	LikeCount int       `json:"like_count" gorm:"not null;default:0" db:"like_count"`
	Status    string    `json:"status" gorm:"size:20;not null;default:published" db:"status"` // published, hidden, deleted
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

func (CommunityComment) TableName() string { return "community_comments" }

// CommunityLike 点赞记录
type CommunityLike struct {
	ID         int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID     int64     `json:"user_id" gorm:"uniqueIndex:uniq_like;not null" db:"user_id"`
	TargetType string    `json:"target_type" gorm:"uniqueIndex:uniq_like;not null" db:"target_type"` // post, comment
	TargetID   int64     `json:"target_id" gorm:"uniqueIndex:uniq_like;not null" db:"target_id"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

func (CommunityLike) TableName() string { return "community_likes" }

// Follow 关注关系（家长之间的关注）
type Follow struct {
	ID          int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	FollowerID  int64     `json:"follower_id" gorm:"uniqueIndex:uniq_follow;not null" db:"follower_id"`
	FollowingID int64     `json:"following_id" gorm:"uniqueIndex:uniq_follow;not null" db:"following_id"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

func (Follow) TableName() string { return "follows" }

// AuthVerification 认证审核
type AuthVerification struct {
	ID           int64      `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID       int64      `json:"user_id" gorm:"index;not null" db:"user_id"`
	Method       string     `json:"method" gorm:"size:20;not null" db:"method"` // student_card, class_group, payment, invite_code
	MaterialImage string    `json:"material_image" gorm:"size:500" db:"material_image"`
	InviteCode   string     `json:"invite_code" gorm:"size:20" db:"invite_code"`
	Status       string     `json:"status" gorm:"size:20;not null;default:pending" db:"status"` // pending, approved, rejected
	ReviewerID   *int64     `json:"reviewer_id" db:"reviewer_id"`
	ReviewNote   string     `json:"review_note" gorm:"type:text" db:"review_note"`
	ReviewedAt   *time.Time `json:"reviewed_at" db:"reviewed_at"`
	CreatedAt    time.Time  `json:"created_at" gorm:"index" db:"created_at"`
}

func (AuthVerification) TableName() string { return "auth_verifications" }

// InviteCode 邀请码
type InviteCode struct {
	ID        int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	Code      string    `json:"code" gorm:"size:20;uniqueIndex;not null" db:"code"`
	InviterID int64     `json:"inviter_id" gorm:"index;not null" db:"inviter_id"`
	MaxUses   int       `json:"max_uses" gorm:"not null;default:3" db:"max_uses"` // 默认 3
	UsedCount int       `json:"used_count" gorm:"not null;default:0" db:"used_count"`
	ExpiresAt time.Time `json:"expires_at" gorm:"not null" db:"expires_at"` // 30 天有效期
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

func (InviteCode) TableName() string { return "invite_codes" }

// ShareRecord 分享记录
type ShareRecord struct {
	ID        int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID    int64     `json:"user_id" gorm:"index;not null" db:"user_id"`
	ReportID  int64     `json:"report_id" gorm:"not null" db:"report_id"`  // 关联分析报告（exam_id）
	ReportType string   `json:"report_type" gorm:"size:20;not null;default:exam" db:"report_type"` // exam, paper
	Channel   string    `json:"channel" gorm:"size:20;not null" db:"channel"` // wechat, moments, group, copy_link
	CreatedAt time.Time `json:"created_at" gorm:"index" db:"created_at"`
}

func (ShareRecord) TableName() string { return "share_records" }

// AnalysisQuota 分析次数配额（复合主键：用户 + 年月）
type AnalysisQuota struct {
	UserID    int64     `json:"user_id" gorm:"primaryKey" db:"user_id"`
	YearMonth string    `json:"year_month" gorm:"primaryKey" db:"year_month"` // 2025-07
	FreeQuota int       `json:"free_quota" gorm:"not null;default:3" db:"free_quota"` // 每月 3 次
	FreeUsed  int       `json:"free_used" gorm:"not null;default:0" db:"free_used"`
	BonusQuota int      `json:"bonus_quota" gorm:"not null;default:0" db:"bonus_quota"` // 分享获取
	BonusUsed int       `json:"bonus_used" gorm:"not null;default:0" db:"bonus_used"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

func (AnalysisQuota) TableName() string { return "analysis_quotas" }

// Notification 通知
type Notification struct {
	ID        int64     `json:"id" gorm:"primaryKey;autoIncrement" db:"id"`
	UserID    int64     `json:"user_id" gorm:"index;not null" db:"user_id"`
	Type      string    `json:"type" gorm:"size:30;not null" db:"type"`
	Title     string    `json:"title" gorm:"size:200;not null" db:"title"`
	Content   string    `json:"content" gorm:"type:text" db:"content"`
	IsRead    bool      `json:"is_read" gorm:"not null;default:false" db:"is_read"`
	RelatedID int64     `json:"related_id" gorm:"default:0" db:"related_id"`
	CreatedAt time.Time `json:"created_at" gorm:"index" db:"created_at"`
}

func (Notification) TableName() string { return "notifications" }
