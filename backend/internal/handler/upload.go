package handler

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// uploadBaseDir 图片落盘目录（相对 CWD，由 main 启动时确保存在）。
var uploadBaseDir = "uploads"

// SetUploadDir 设置图片上传根目录（main 启动时调用）。
func SetUploadDir(dir string) {
	uploadBaseDir = dir
}

// UploadHandler 开发态图片上传（社区发帖/评论图片）。
type UploadHandler struct{}

// NewUploadHandler 构造上传 Handler。
func NewUploadHandler() *UploadHandler {
	return &UploadHandler{}
}

// Image 上传单张图片 POST /api/upload （需登录）
//
// 开发态：保存到本地 uploads/，返回可经反代访问的 URL（/api/uploads/<file>）。
// 生产应替换为对象存储（OSS/COS/S3）并做大小/类型校验。
func (h *UploadHandler) Image(c *gin.Context) {
	_ = currentUserID(c) // 需登录（路由已挂 AuthMiddleware）
	file, err := c.FormFile("file")
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供图片文件(file)")
		return
	}
	// 类型与大小粗校验
	ext := strings.ToLower(filepath.Ext(file.Filename))
	if ext == "" {
		ext = ".jpg"
	}
	switch ext {
	case ".jpg", ".jpeg", ".png", ".gif", ".webp":
	default:
		Fail(c, http.StatusBadRequest, 400, "仅支持 jpg/png/gif/webp 图片")
		return
	}
	if file.Size > 8<<20 { // 8MB
		Fail(c, http.StatusBadRequest, 400, "图片不能超过 8MB")
		return
	}

	_ = os.MkdirAll(uploadBaseDir, 0o755)
	name := fmt.Sprintf("%d_%d%s", time.Now().UnixNano(), currentUserID(c), ext)
	dst := filepath.Join(uploadBaseDir, name)
	out, err := os.Create(dst)
	if err != nil {
		mapErr(c, err)
		return
	}
	defer out.Close()
	src, err := file.Open()
	if err != nil {
		mapErr(c, err)
		return
	}
	defer src.Close()
	if _, err = io.Copy(out, src); err != nil {
		mapErr(c, err)
		return
	}

	OK(c, gin.H{"url": "/api/uploads/" + name})
}
