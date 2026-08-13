package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/peidu-community/backend/internal/config"
	"github.com/peidu-community/backend/internal/handler"
	"github.com/peidu-community/backend/internal/middleware"
	"github.com/peidu-community/backend/internal/model"
	"github.com/peidu-community/backend/internal/service"
	"github.com/peidu-community/backend/internal/tracker"
)

func main() {
	cfg := config.Load()
	gin.SetMode(cfg.Server.Mode)

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORSMiddleware())
	r.Use(middleware.LoggerMiddleware())

	// 开发态图片上传目录（与静态服务路径一致）
	_ = os.MkdirAll("uploads", 0o755)
	handler.SetUploadDir("uploads")

	// ---------- 数据库连接（best-effort：失败不致命，便于无 PG 环境下冒烟）----------
	var db *gorm.DB
	dsn := cfg.Database.DSN()
	conn, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
	if err != nil {
		log.Printf("[WARN] 数据库连接失败，相关接口将返回 503（%v）。\n"+
			"        本地启动请设置环境变量：DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME，\n"+
			"        或先启动 PostgreSQL 并建库 `peidu_community`。", err)
	} else {
		db = conn
		if err = autoMigrate(db); err != nil {
			log.Printf("[WARN] 表结构迁移失败：%v", err)
		} else {
			seedDefaultCircles(db)
			seedKnowledgePoints(db)
			seedSamplePosts(db)
			seedInviteCode(db)
		}
	}

	// ---------- 依赖装配 ----------
	tk := tracker.New()
	deps := service.NewDeps(db, cfg, tk)
	authSvc := service.NewAuthService(deps)
	calSvc := service.NewCalendarService(deps)
	paperSvc := service.NewPaperService(deps)
	studentSvc := service.NewStudentService(deps)
	commSvc := service.NewCommunityService(deps)
	inviteSvc := service.NewInviteService(deps)
	notifSvc := service.NewNotificationService(deps)
	uploadH := handler.NewUploadHandler()

	healthH := handler.NewHealthHandler()
	authH := handler.NewAuthHandler(authSvc)
	calH := handler.NewCalendarHandler(calSvc)
	paperH := handler.NewPaperHandler(paperSvc)
	studentH := handler.NewStudentHandler(studentSvc)
	commH := handler.NewCommunityHandler(commSvc)
	inviteH := handler.NewInviteHandler(inviteSvc)
	notifH := handler.NewNotificationHandler(notifSvc)

	// ---------- 路由 ----------
	r.GET("/api/health", healthH.Ping)

	api := r.Group("/api")
	{
		// 公开接口
		api.POST("/auth/send-sms", authH.SendSMS)
		api.POST("/auth/login", authH.Login)
		api.GET("/calendar/countdown", calH.Countdown)
		api.GET("/calendar/templates", calH.Templates)
		api.GET("/community/circles", commH.ListCircles)
		// 开发态图片静态服务（公开，便于 <img> 直接加载）
		api.Static("/uploads", "./uploads")
	}

	// 需登录
	auth := api.Group("")
	auth.Use(middleware.AuthMiddleware(cfg.JWT.Secret))
	{
		auth.GET("/users/profile", authH.GetProfile)
		auth.POST("/users/verification", authH.SubmitVerification)
		auth.GET("/users/verification/status", authH.GetVerificationStatus)
		auth.GET("/users/quota", paperH.GetQuota)

		auth.GET("/calendar/events", calH.ListEvents)
		auth.POST("/calendar/events", calH.CreateEvent)
		auth.POST("/calendar/exams", calH.RecordExam)

		auth.GET("/papers/:id/report", paperH.GetReport)
		auth.GET("/papers/trend", paperH.ScoreTrend)
		auth.GET("/analysis/radar", paperH.Radar)
		auth.GET("/papers/knowledge/:kpId/trend", paperH.KnowledgeTrend)
		auth.GET("/papers/tier-distribution", paperH.TierDistribution)

		auth.GET("/community/posts", commH.ListPosts)
		auth.GET("/community/posts/:id", commH.GetPost)
		auth.GET("/community/posts/:id/comments", commH.ListComments)

		auth.POST("/invites/generate", inviteH.Generate)
		auth.GET("/invites", inviteH.List)
		auth.POST("/invites/use", inviteH.Use)

		// 图片上传 / 分析列表概览 / 消息通知
		auth.POST("/upload", uploadH.Image)
		auth.GET("/students", studentH.List)
		auth.GET("/papers", paperH.ListMine)
		auth.GET("/papers/overview", paperH.Overview)
		auth.GET("/notifications", notifH.List)
		auth.POST("/notifications/read", notifH.Read)

		// 审核后台（模拟人工）
		auth.POST("/admin/verification/review", authH.ReviewVerification)
		auth.POST("/admin/posts/review", commH.ReviewPost)
	}

		// 需完成家长认证
	verified := api.Group("")
	verified.Use(middleware.AuthMiddleware(cfg.JWT.Secret))
	verified.Use(middleware.VerifiedMiddleware(db))
	{
		verified.POST("/papers/upload", paperH.Upload)
		verified.POST("/papers/scan", paperH.Scan)
		verified.POST("/papers/:id/confirm", paperH.Confirm)
		verified.POST("/papers/:id/share", paperH.Share)

		verified.POST("/community/posts", commH.CreatePost)
		verified.POST("/community/comments", commH.Comment)
		verified.POST("/community/like", commH.Like)
		verified.POST("/community/follow", commH.Follow)
		verified.POST("/community/share-report", commH.ShareToCommunity)
	}

	// ---------- 启动 ----------
	srv := &http.Server{
		Addr:         ":" + strconv.Itoa(cfg.Server.Port),
		Handler:      r,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	go func() {
		log.Printf("陪读社区后端启动，端口: %d", cfg.Server.Port)
		if e := srv.ListenAndServe(); e != nil && e != http.ErrServerClosed {
			log.Fatalf("服务启动失败: %v", e)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("正在关闭服务...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if e := srv.Shutdown(ctx); e != nil {
		log.Fatalf("服务关闭异常: %v", e)
	}
	log.Println("服务已安全关闭")
}

// autoMigrate 创建/更新表结构（以 model 为准）
func autoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&model.User{},
		&model.Student{},
		&model.CalendarEvent{},
		&model.Exam{},
		&model.Paper{},
		&model.PaperItem{},
		&model.KnowledgePoint{},
		&model.ExamKPResult{},
		&model.CommunityCircle{},
		&model.CommunityPost{},
		&model.CommunityComment{},
		&model.CommunityLike{},
		&model.Follow{},
		&model.AuthVerification{},
		&model.InviteCode{},
		&model.ShareRecord{},
		&model.AnalysisQuota{},
		&model.Notification{},
	)
}

// seedDefaultCircles 预置默认圈子（FR-COM-001），仅当表为空时插入
func seedDefaultCircles(db *gorm.DB) {
	var cnt int64
	db.Model(&model.CommunityCircle{}).Count(&cnt)
	if cnt > 0 {
		return
	}
	circles := []model.CommunityCircle{
		{Name: "高三陪读圈", Category: "grade", Description: "高三家长交流陪读经验"},
		{Name: "高一高二预备圈", Category: "grade", Description: "高一高二家长提前准备"},
		{Name: "广东陪读圈", Category: "region", Description: "广东地区陪读家长交流"},
		{Name: "北京陪读圈", Category: "region", Description: "北京地区陪读家长交流"},
		{Name: "数学交流圈", Category: "subject", Description: "数学其它与经验分享"},
		{Name: "语文交流圈", Category: "subject", Description: "语文其它与经验分享"},
		{Name: "英语交流圈", Category: "subject", Description: "英语其它与经验分享"},
		{Name: "营养食谱", Category: "topic", Description: "陪读期间营养餐分享"},
		{Name: "心理调适", Category: "topic", Description: "考前心理调节与压力管理"},
		{Name: "志愿填报", Category: "topic", Description: "高考志愿填报经验交流"},
		{Name: "政策解读", Category: "topic", Description: "高考政策解读与讨论"},
	}
	db.Create(&circles)
	log.Println("[INFO] 已预置默认圈子")
}

// seedKnowledgePoints 预置知识点表（来自知识图谱 JSON，仅当表为空时插入）。
// 这样试卷分析聚合时 findKPID 才能命中 knowledge_point_id，单知识点趋势查询才有效。
func seedKnowledgePoints(db *gorm.DB) {
	var cnt int64
	db.Model(&model.KnowledgePoint{}).Count(&cnt)
	if cnt > 0 {
		return
	}
	path := findGraphPath()
	if path == "" {
		log.Println("[WARN] 未找到 knowledge_graph.json，跳过知识点种子")
		return
	}
	data, err := os.ReadFile(path)
	if err != nil {
		log.Printf("[WARN] 读取知识图谱失败：%v", err)
		return
	}
	var g struct {
		Nodes []struct {
			ID          string `json:"id"`
			Subject     string `json:"subject"`
			Chapter     string `json:"chapter"`
			Name        string `json:"name"`
			Level       int    `json:"level"`
			Description string `json:"description"`
		} `json:"nodes"`
	}
	if err = json.Unmarshal(data, &g); err != nil {
		log.Printf("[WARN] 解析知识图谱失败：%v", err)
		return
	}
	pts := make([]model.KnowledgePoint, 0, len(g.Nodes))
	for _, n := range g.Nodes {
		pts = append(pts, model.KnowledgePoint{
			Name:        n.Name,
			Subject:     n.Subject,
			Chapter:     n.Chapter,
			Level:       n.Level,
			Description: n.Description,
			Neo4jID:     n.ID,
		})
	}
	if err = db.Create(&pts).Error; err != nil {
		log.Printf("[WARN] 知识点种子写入失败：%v", err)
		return
	}
	log.Printf("[INFO] 已预置 %d 个知识点（来源：%s）", len(pts), path)
}

// seedSamplePosts 预置社区样例帖子（体验态），仅当无已发布帖子时插入
func seedSamplePosts(db *gorm.DB) {
	var cnt int64
	db.Model(&model.CommunityPost{}).Where("status = ?", "published").Count(&cnt)
	if cnt > 0 {
		return
	}
	// 样例作者
	var author model.User
	db.Where("phone = ?", "13900000000").FirstOrCreate(&author, model.User{
		Phone:    "13900000000",
		Nickname: "陪读学姐·王老师",
	})
	// 圈子名 -> id 映射
	circles := []model.CommunityCircle{}
	db.Find(&circles)
	circleID := map[string]int64{}
	var firstID int64
	for _, c := range circles {
		circleID[c.Name] = c.ID
		if firstID == 0 {
			firstID = c.ID
		}
	}
	idOf := func(name string) int64 {
		if v, ok := circleID[name]; ok {
			return v
		}
		return firstID
	}
	posts := []model.CommunityPost{
		{
			UserID: author.ID, CircleID: idOf("高三陪读圈"),
			Title:   "高三最后一年，陪读家长如何不焦虑？",
			Content: "孩子进入高三后，我家氛围一度很紧张。后来我们约定：只问努力不问排名，每晚留 15 分钟纯聊天。半年下来，孩子状态稳了，我也松了口气。共勉。",
			Status: "published", LikeCount: 128, CommentCount: 34, ViewCount: 2300, IsPinned: true,
		},
		{
			UserID: author.ID, CircleID: idOf("数学交流圈"),
			Title:   "一模数学 90 分，最后半年还能追吗？",
			Content: "一模数学只考了 90，孩子很受打击。我们对照试卷分析把错题按知识点归类，发现 60% 丢在解析几何和概率。建议先抓基础题型，别急着刷压轴。",
			Status: "published", LikeCount: 86, CommentCount: 21, ViewCount: 1510,
		},
		{
			UserID: author.ID, CircleID: idOf("心理调适"),
			Title:   "考前失眠怎么办？亲测有用的方法",
			Content: "考前一周孩子开始失眠。我们尝试了：固定作息、睡前半小时不碰手机、白噪音+腹式呼吸。三天后明显改善。家长先稳住情绪，孩子才会跟着稳。",
			Status: "published", LikeCount: 203, CommentCount: 47, ViewCount: 3120,
		},
		{
			UserID: author.ID, CircleID: idOf("营养食谱"),
			Title:   "高三早餐一周不重样（附清单）",
			Content: "周一杂粮粥+鸡蛋+牛奶，周二全麦三明治，周三豆浆+包子+水果……保证蛋白质和碳水的搭配，孩子上午听课不容易犯困。需要的家长自取清单。",
			Status: "published", LikeCount: 154, CommentCount: 28, ViewCount: 1980,
		},
		{
			UserID: author.ID, CircleID: idOf("志愿填报"),
			Title:   "出分前就要准备的志愿填报资料",
			Content: "别等出分再慌。现在可以做的：① 估往年位次对应的院校区间；② 理清孩子选科能报的专业；③ 和家人统一“地域/学校/专业”优先级。出分后照表填即可。",
			Status: "published", LikeCount: 97, CommentCount: 19, ViewCount: 1760,
		},
		{
			UserID: author.ID, CircleID: idOf("政策解读"),
			Title:   "今年高考报名这些材料提前备好",
			Content: "户口本、身份证、学籍证明是基本项；随迁子女注意社保与居住证年限要求。各省时间不一，建议现在就关注本省教育考试院通知，别错过窗口。",
			Status: "published", LikeCount: 73, CommentCount: 12, ViewCount: 1320,
		},
	}
	if err := db.Create(&posts).Error; err != nil {
		log.Printf("[WARN] 社区样例帖子写入失败：%v", err)
		return
	}
	log.Printf("[INFO] 已预置 %d 条社区样例帖子", len(posts))
}

// seedInviteCode 预置一个公开邀请码（体验态），供全新体验用户一键完成家长认证。
// 幂等：仅当该固定码不存在时插入；不依赖其它邀请码是否存在。
func seedInviteCode(db *gorm.DB) {
	const demoCode = "PAIDU8"
	var cnt int64
	db.Model(&model.InviteCode{}).Where("code = ?", demoCode).Count(&cnt)
	if cnt > 0 {
		return
	}
	// 邀请人复用样例作者账号，确保 inviter 存在且可获奖励额度。
	var inviter model.User
	db.Where("phone = ?", "13900000000").FirstOrCreate(&inviter, model.User{
		Phone:    "13900000000",
		Nickname: "陪读学姐·王老师",
	})
	ic := model.InviteCode{
		Code:      demoCode,
		InviterID: inviter.ID,
		MaxUses:   9999,
		UsedCount: 0,
		ExpiresAt: time.Now().Add(3650 * 24 * time.Hour), // 约 10 年有效，纯体验用
	}
	if err := db.Create(&ic).Error; err != nil {
		log.Printf("[WARN] 预置邀请码失败：%v", err)
		return
	}
	log.Printf("[INFO] 已预置公开体验邀请码：%s（任意新用户可在「家长认证」页输入该码一键通过）", demoCode)
}

// findGraphPath 在常见位置中寻找 knowledge_graph.json
func findGraphPath() string {
	candidates := []string{
		"../database/knowledge_graph.json",
		"../../database/knowledge_graph.json",
		"database/knowledge_graph.json",
		"/workspace/peidu-community/database/knowledge_graph.json",
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			abs, _ := filepath.Abs(c)
			return abs
		}
	}
	return ""
}
