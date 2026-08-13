package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// PaperHandler 试卷分析接口
type PaperHandler struct {
	svc *service.PaperService
}

// NewPaperHandler 构造试卷 Handler
func NewPaperHandler(svc *service.PaperService) *PaperHandler {
	return &PaperHandler{svc: svc}
}

// GetQuota 查询剩余分析次数 GET /api/users/quota
func (h *PaperHandler) GetQuota(c *gin.Context) {
	uid := currentUserID(c)
	free, bonus, err := h.svc.GetQuota(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, gin.H{"free_remain": free, "bonus_remain": bonus, "total_remain": free + bonus})
}

// Scan 上传试卷仅做 OCR 识别 POST /api/papers/scan （Phase 1）
func (h *PaperHandler) Scan(c *gin.Context) {
	uid := currentUserID(c)
	file, err := c.FormFile("file")
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "请上传试卷图片(file)")
		return
	}
	studentID, _ := strconv.ParseInt(c.PostForm("student_id"), 10, 64)
	subject := c.PostForm("subject")
	examName := c.PostForm("exam_name")
	if subject == "" {
		Fail(c, http.StatusBadRequest, 400, "请指定科目(subject)")
		return
	}
	f, err := file.Open()
	if err != nil {
		mapErr(c, err)
		return
	}
	defer f.Close()

	result, err := h.svc.Scan(c.Request.Context(), uid, studentID, subject, examName, f, file.Filename)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, result)
}

// Confirm 确认错题并生成报告 POST /api/papers/:id/confirm （Phase 2）
func (h *PaperHandler) Confirm(c *gin.Context) {
	uid := currentUserID(c)
	paperID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "paper id 无效")
		return
	}
	var req struct {
		Subject   string                `json:"subject"`
		ExamName  string                `json:"exam_name"`
		StudentID int64                 `json:"student_id"`
		Items     []service.ConfirmItem `json:"items"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求参数格式错误")
		return
	}
	if req.Subject == "" {
		Fail(c, http.StatusBadRequest, 400, "请指定科目(subject)")
		return
	}

	paper, err := h.svc.Confirm(c.Request.Context(), uid, paperID, req.Subject, req.ExamName, req.StudentID, req.Items)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, paper)
}

// Upload 上传试卷并分析 POST /api/papers/upload （需家长认证）
func (h *PaperHandler) Upload(c *gin.Context) {
	uid := currentUserID(c)
	file, err := c.FormFile("file")
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "请上传试卷图片(file)")
		return
	}
	studentID, _ := strconv.ParseInt(c.PostForm("student_id"), 10, 64)
	subject := c.PostForm("subject")
	examName := c.PostForm("exam_name")
	if subject == "" {
		Fail(c, http.StatusBadRequest, 400, "请指定科目(subject)")
		return
	}
	f, err := file.Open()
	if err != nil {
		mapErr(c, err)
		return
	}
	defer f.Close()

	paper, err := h.svc.Upload(c.Request.Context(), uid, studentID, subject, examName, f, file.Filename)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, paper)
}

// GetReport 获取试卷分析报告 GET /api/papers/:id/report
func (h *PaperHandler) GetReport(c *gin.Context) {
	uid := currentUserID(c)
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "paper id 无效")
		return
	}
	report, err := h.svc.GetReport(c.Request.Context(), uid, id)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, report)
}

// ScoreTrend 得分率趋势 GET /api/papers/trend?student_id=&subject=&academic_year=
func (h *PaperHandler) ScoreTrend(c *gin.Context) {
	uid := currentUserID(c)
	studentID, _ := strconv.ParseInt(c.Query("student_id"), 10, 64)
	subject := c.Query("subject")
	academicYear := c.Query("academic_year")
	exams, err := h.svc.ScoreTrend(c.Request.Context(), uid, studentID, subject, academicYear)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, exams)
}

// Radar 能力雷达数据。
// GET /api/analysis/radar?student_id=&academic_year=            -> 学生维度（各科最新得分率）
// GET /api/analysis/radar?student_id=&subject=&academic_year=   -> 科目维度（该科最新考试各知识点掌握度）
func (h *PaperHandler) Radar(c *gin.Context) {
	uid := currentUserID(c)
	studentID, _ := strconv.ParseInt(c.Query("student_id"), 10, 64)
	if studentID <= 0 {
		Fail(c, http.StatusBadRequest, 400, "请指定 student_id")
		return
	}
	subject := c.Query("subject")
	academicYear := c.Query("academic_year")
	var (
		resp *service.RadarResponse
		err  error
	)
	if subject != "" {
		resp, err = h.svc.RadarSubject(c.Request.Context(), uid, studentID, subject, academicYear)
	} else {
		resp, err = h.svc.RadarStudent(c.Request.Context(), uid, studentID, academicYear)
	}
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, resp)
}

// KnowledgeTrend 单知识点错误率趋势 GET /api/papers/knowledge/:kpId/trend
func (h *PaperHandler) KnowledgeTrend(c *gin.Context) {
	uid := currentUserID(c)
	kpID, err := strconv.ParseInt(c.Param("kpId"), 10, 64)
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "kpId 无效")
		return
	}
	results, err := h.svc.KnowledgeTrend(c.Request.Context(), uid, kpID)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, results)
}

// TierDistribution 三档分布 GET /api/papers/tier-distribution?exam_id=
func (h *PaperHandler) TierDistribution(c *gin.Context) {
	uid := currentUserID(c)
	examID, _ := strconv.ParseInt(c.Query("exam_id"), 10, 64)
	dist, err := h.svc.TierDistribution(c.Request.Context(), uid, examID)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, dist)
}

// Share 分享分析报告 GET/POST /api/papers/:id/share?channel=
func (h *PaperHandler) Share(c *gin.Context) {
	uid := currentUserID(c)
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "paper id 无效")
		return
	}
	channel := c.Query("channel")
	if channel == "" {
		channel = "wechat"
	}
	if err := h.svc.Share(c.Request.Context(), uid, id, channel); err != nil {
		mapErr(c, err)
		return
	}
	OK(c, gin.H{"shared": true, "channel": channel})
}

// ListMine 我的过往分析列表 GET /api/papers （需登录）
func (h *PaperHandler) ListMine(c *gin.Context) {
	uid := currentUserID(c)
	list, err := h.svc.ListMyAnalyses(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, list)
}

// Overview 整体分析统计 GET /api/papers/overview （需登录）
func (h *PaperHandler) Overview(c *gin.Context) {
	uid := currentUserID(c)
	ov, err := h.svc.GetOverview(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, ov)
}
