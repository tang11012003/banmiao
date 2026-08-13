package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// InviteHandler 邀请码接口
type InviteHandler struct {
	svc *service.InviteService
}

// NewInviteHandler 构造邀请码 Handler
func NewInviteHandler(svc *service.InviteService) *InviteHandler {
	return &InviteHandler{svc: svc}
}

// Generate 生成邀请码 POST /api/invites/generate
func (h *InviteHandler) Generate(c *gin.Context) {
	uid := currentUserID(c)
	ic, err := h.svc.Generate(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, ic)
}

// List 我的邀请码 GET /api/invites
func (h *InviteHandler) List(c *gin.Context) {
	uid := currentUserID(c)
	list, err := h.svc.List(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, list)
}

// Use 使用邀请码 POST /api/invites/use
func (h *InviteHandler) Use(c *gin.Context) {
	var body struct {
		Code string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供邀请码")
		return
	}
	uid := currentUserID(c)
	av, err := h.svc.Use(c.Request.Context(), uid, body.Code)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, av)
}
