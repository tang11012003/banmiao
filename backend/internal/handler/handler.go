package handler

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// dbErr 将数据库不可用等底层错误映射为合适的 HTTP 状态码与提示
func dbErr(c *gin.Context, err error, fallbackMsg string) {
	if errors.Is(err, service.ErrDBUnavailable) {
		Fail(c, http.StatusServiceUnavailable, 503, "数据库未连接，请稍后重试或联系管理员")
		return
	}
	Fail(c, http.StatusBadRequest, 400, fallbackMsg+":"+err.Error())
}

// APIResponse 统一返回结构
type APIResponse struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// OK 成功返回
func OK(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, APIResponse{Code: 0, Message: "ok", Data: data})
}

// Created 创建成功
func Created(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, APIResponse{Code: 0, Message: "ok", Data: data})
}

// Fail 失败返回
func Fail(c *gin.Context, httpStatus, code int, message string) {
	c.JSON(httpStatus, APIResponse{Code: code, Message: message})
}

// currentUserID 从 JWT 上下文取出用户 ID
func currentUserID(c *gin.Context) int64 {
	if v, ok := c.Get("user_id"); ok {
		if id, ok := v.(int64); ok {
			return id
		}
	}
	return 0
}

// HealthResponse 健康检查响应
type HealthResponse struct {
	Status    string `json:"status"`
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
}

// HealthHandler 健康检查处理器
type HealthHandler struct{}

// NewHealthHandler 创建健康检查处理器
func NewHealthHandler() *HealthHandler { return &HealthHandler{} }

// Ping 健康检查接口 GET /api/health
func (h *HealthHandler) Ping(c *gin.Context) {
	c.JSON(http.StatusOK, HealthResponse{
		Status:    "ok",
		Version:   "1.0.0",
		Timestamp: time.Now().Format(time.RFC3339),
	})
}
