package middleware

import (
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// CORSMiddleware 处理跨域请求
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

// LoggerMiddleware 请求日志中间件
func LoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path

		c.Next()

		latency := time.Since(start)
		statusCode := c.Writer.Status()

		log.Printf("[%d] %s %s | %v | %s",
			statusCode,
			c.Request.Method,
			path,
			latency,
			c.ClientIP(),
		)
	}
}

// AuthMiddleware JWT 认证中间件
func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenString := c.GetHeader("Authorization")
		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "缺少认证令牌"})
			c.Abort()
			return
		}

		// 去除 "Bearer " 前缀
		if len(tokenString) > 7 && tokenString[:7] == "Bearer " {
			tokenString = tokenString[7:]
		}

		claims, err := ParseJWT(tokenString, jwtSecret)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "无效的认证令牌"})
			c.Abort()
			return
		}

		// 将用户信息注入上下文
		c.Set("user_id", claims.UserID)
		c.Set("user_phone", claims.Phone)
		c.Set("user_role", claims.Role)

		c.Next()
	}
}

// VerifiedMiddleware 检查用户是否已完成家长认证。
//
// 注意：认证状态（role=parent）由 DB 实时回查，而非信任 JWT 中的静态 role 声明。
// 这样「使用邀请码秒过」「后台审核通过」后，即便 JWT 仍是登录时签发的旧角色，
// 后续受保护接口也能立即放行，无需用户重新登录。
// 当 db 为 nil（无数据库模式）时，回退为信任 JWT 声明，保证冒烟可用。
func VerifiedMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uidVal, ok := c.Get("user_id")
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "缺少用户身份"})
			c.Abort()
			return
		}
		uid, ok := uidVal.(int64)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "用户身份无效"})
			c.Abort()
			return
		}

		// 无 DB 模式：信任 JWT 声明中的 role（登录态冒烟）。
		if db == nil {
			role, exists := c.Get("user_role")
			if !exists || role.(string) != "parent" {
				c.JSON(http.StatusForbidden, gin.H{
					"error":   "请先完成家长身份确认",
					"code":    "AUTH_REQUIRED",
					"message": "上传试卷、发帖等操作需要完成家长身份确认",
				})
				c.Abort()
				return
			}
			c.Next()
			return
		}

		// 实时回查 DB 当前角色。
		var role string
		if err := db.Model(&struct{}{}).
			Table("users").
			Where("id = ?", uid).
			Pluck("role", &role).Error; err != nil || role == "" {
			// 查询失败或用户不存在：回退 JWT 声明，避免硬阻断。
			r, exists := c.Get("user_role")
			if !exists || r.(string) != "parent" {
				c.JSON(http.StatusForbidden, gin.H{
					"error":   "请先完成家长身份确认",
					"code":    "AUTH_REQUIRED",
					"message": "上传试卷、发帖等操作需要完成家长身份确认",
				})
				c.Abort()
				return
			}
			c.Next()
			return
		}

		if role != "parent" {
			c.JSON(http.StatusForbidden, gin.H{
				"error":   "请先完成家长身份确认",
				"code":    "AUTH_REQUIRED",
				"message": "上传试卷、发帖等操作需要完成家长身份确认",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

// RateLimitMiddleware 简单限流中间件（基于 Redis 实现，此处为占位）
func RateLimitMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: 基于 Redis 的滑动窗口限流
		c.Next()
	}
}
