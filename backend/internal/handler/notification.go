package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// NotificationHandler 消息/通知接口
type NotificationHandler struct {
	svc *service.NotificationService
}

// NewNotificationHandler 构造通知 Handler
func NewNotificationHandler(svc *service.NotificationService) *NotificationHandler {
	return &NotificationHandler{svc: svc}
}

// List 我的通知列表 GET /api/notifications （需登录）
func (h *NotificationHandler) List(c *gin.Context) {
	uid := currentUserID(c)
	list, err := h.svc.List(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, list)
}

// Read 标记通知已读 POST /api/notifications/read （需登录）
func (h *NotificationHandler) Read(c *gin.Context) {
	var body struct {
		ID int64 `json:"id"`
	}
	_ = c.ShouldBindJSON(&body)
	uid := currentUserID(c)
	if err := h.svc.MarkRead(c.Request.Context(), uid, body.ID); err != nil {
		mapErr(c, err)
		return
	}
	OK(c, gin.H{"ok": true})
}
