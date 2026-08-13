package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// AuthHandler 认证相关接口
type AuthHandler struct {
	svc *service.AuthService
}

// NewAuthHandler 构造认证 Handler
func NewAuthHandler(svc *service.AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

// SendSMS 发送登录短信验证码 POST /api/auth/send-sms
func (h *AuthHandler) SendSMS(c *gin.Context) {
	var body struct {
		Phone string `json:"phone" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供手机号")
		return
	}
	code, err := h.svc.SendSMS(c.Request.Context(), body.Phone)
	if err != nil {
		mapErr(c, err)
		return
	}
	// 开发态直接返回验证码，便于联调
	OK(c, gin.H{"phone": body.Phone, "dev_code": code})
}

// Login 短信验证码登录 POST /api/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
	var body struct {
		Phone string `json:"phone" binding:"required"`
		Code  string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供手机号和验证码")
		return
	}
	token, user, err := h.svc.Login(c.Request.Context(), body.Phone, body.Code)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, gin.H{"token": token, "user": user})
}

// GetProfile 获取当前用户资料 GET /api/users/profile
func (h *AuthHandler) GetProfile(c *gin.Context) {
	uid := currentUserID(c)
	user, err := h.svc.GetProfile(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, user)
}

// SubmitVerification 提交家长认证 POST /api/users/verification
func (h *AuthHandler) SubmitVerification(c *gin.Context) {
	var body struct {
		Method        string `json:"method" binding:"required"`
		MaterialImage string `json:"material_image"`
		InviteCode    string `json:"invite_code"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供认证方式")
		return
	}
	uid := currentUserID(c)
	av, err := h.svc.SubmitVerification(c.Request.Context(), uid, body.Method, body.MaterialImage, body.InviteCode)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, av)
}

// GetVerificationStatus 查询认证状态 GET /api/users/verification/status
func (h *AuthHandler) GetVerificationStatus(c *gin.Context) {
	uid := currentUserID(c)
	av, err := h.svc.GetVerificationStatus(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, av)
}

// ReviewVerification 后台审核认证（模拟人工） POST /api/admin/verification/review
func (h *AuthHandler) ReviewVerification(c *gin.Context) {
	var body struct {
		VerificationID int64  `json:"verification_id" binding:"required"`
		Approve        bool   `json:"approve"`
		Note           string `json:"note"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供 verification_id")
		return
	}
	reviewer := currentUserID(c)
	av, err := h.svc.ReviewVerification(c.Request.Context(), body.VerificationID, reviewer, body.Approve, body.Note)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, av)
}
