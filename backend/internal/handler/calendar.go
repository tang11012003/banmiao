package handler

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// CalendarHandler 高考日历接口
type CalendarHandler struct {
	svc *service.CalendarService
}

// NewCalendarHandler 构造日历 Handler
func NewCalendarHandler(svc *service.CalendarService) *CalendarHandler {
	return &CalendarHandler{svc: svc}
}

// Countdown 高考倒计时 GET /api/calendar/countdown
func (h *CalendarHandler) Countdown(c *gin.Context) {
	days, date, err := h.svc.Countdown()
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, gin.H{"days": days, "gaokao_date": date})
}

// Templates 官方节点模板 GET /api/calendar/templates
func (h *CalendarHandler) Templates(c *gin.Context) {
	OK(c, h.svc.Templates())
}

// ListEvents 列出用户日历事件 GET /api/calendar/events?student_id=
func (h *CalendarHandler) ListEvents(c *gin.Context) {
	uid := currentUserID(c)
	studentID, _ := strconv.ParseInt(c.Query("student_id"), 10, 64)
	events, err := h.svc.ListEvents(c.Request.Context(), uid, studentID)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, events)
}

// CreateEvent 创建日历事件 POST /api/calendar/events
func (h *CalendarHandler) CreateEvent(c *gin.Context) {
	var body service.CreateEventInput
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, 400, 400, "参数错误: "+err.Error())
		return
	}
	uid := currentUserID(c)
	ev, err := h.svc.CreateEvent(c.Request.Context(), uid, body)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, ev)
}

// RecordExam 记录模拟考成绩 POST /api/calendar/exams
func (h *CalendarHandler) RecordExam(c *gin.Context) {
	var body service.RecordExamInput
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, 400, 400, "参数错误: "+err.Error())
		return
	}
	uid := currentUserID(c)
	exam, err := h.svc.RecordExam(c.Request.Context(), uid, body)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, exam)
}
