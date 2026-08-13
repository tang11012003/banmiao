package handler

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// mapErr 将 service 层语义错误映射为合适的 HTTP 响应
func mapErr(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrDBUnavailable):
		dbErr(c, err, "数据库未连接")
	case errors.Is(err, service.ErrNotFound):
		Fail(c, http.StatusNotFound, 404, "资源不存在")
	case errors.Is(err, service.ErrNotVerified):
		Fail(c, http.StatusForbidden, 403, "无权访问该资源")
	case errors.Is(err, service.ErrQuotaExhausted):
		Fail(c, http.StatusForbidden, 403, "本月分析次数已用尽，分享到社区可获取更多次数")
	default:
		Fail(c, http.StatusBadRequest, 400, err.Error())
	}
}
