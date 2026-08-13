package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// StudentHandler 学生（孩子）接口
type StudentHandler struct {
	svc *service.StudentService
}

// NewStudentHandler 构造学生 Handler
func NewStudentHandler(svc *service.StudentService) *StudentHandler {
	return &StudentHandler{svc: svc}
}

// List 当前用户的学生列表（含可用科目与学年） GET /api/students
func (h *StudentHandler) List(c *gin.Context) {
	uid := currentUserID(c)
	views, err := h.svc.List(c.Request.Context(), uid)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, views)
}
