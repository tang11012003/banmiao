package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/peidu-community/backend/internal/service"
)

// CommunityHandler 社区接口
type CommunityHandler struct {
	svc *service.CommunityService
}

// NewCommunityHandler 构造社区 Handler
func NewCommunityHandler(svc *service.CommunityService) *CommunityHandler {
	return &CommunityHandler{svc: svc}
}

// ListCircles 圈子列表 GET /api/community/circles
func (h *CommunityHandler) ListCircles(c *gin.Context) {
	circles, err := h.svc.ListCircles(c.Request.Context())
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, circles)
}

// ListPosts 帖子列表 GET /api/community/posts?circle_id=&limit=&offset=
func (h *CommunityHandler) ListPosts(c *gin.Context) {
	circleID, _ := strconv.ParseInt(c.Query("circle_id"), 10, 64)
	limit, _ := strconv.Atoi(c.Query("limit"))
	offset, _ := strconv.Atoi(c.Query("offset"))
	posts, err := h.svc.ListPosts(c.Request.Context(), int(circleID), limit, offset)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, posts)
}

// GetPost 帖子详情 GET /api/community/posts/:id
func (h *CommunityHandler) GetPost(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "post id 无效")
		return
	}
	post, err := h.svc.GetPost(c.Request.Context(), id)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, post)
}

// ListComments 评论列表 GET /api/community/posts/:id/comments
func (h *CommunityHandler) ListComments(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "post id 无效")
		return
	}
	comments, err := h.svc.ListComments(c.Request.Context(), id)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, comments)
}

// CreatePost 发帖 POST /api/community/posts （需家长认证）
func (h *CommunityHandler) CreatePost(c *gin.Context) {
	var body service.CreatePostInput
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误: "+err.Error())
		return
	}
	uid := currentUserID(c)
	post, err := h.svc.CreatePost(c.Request.Context(), uid, body)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, post)
}

// Comment 评论 POST /api/community/comments （需家长认证）
func (h *CommunityHandler) Comment(c *gin.Context) {
	var body struct {
		PostID   int64  `json:"post_id" binding:"required"`
		Content  string `json:"content"`
		Image    string `json:"image"`
		ParentID int64  `json:"parent_id"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供 post_id 与 content")
		return
	}
	uid := currentUserID(c)
	cm, err := h.svc.Comment(c.Request.Context(), uid, body.PostID, body.Content, body.ParentID, body.Image)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, cm)
}

// Like 点赞/取消 POST /api/community/like （需家长认证）
func (h *CommunityHandler) Like(c *gin.Context) {
	var body struct {
		TargetType string `json:"target_type" binding:"required"`
		TargetID   int64  `json:"target_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供 target_type 与 target_id")
		return
	}
	uid := currentUserID(c)
	liked, err := h.svc.Like(c.Request.Context(), uid, body.TargetType, body.TargetID)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, gin.H{"liked": liked})
}

// Follow 关注/取关 POST /api/community/follow （需家长认证）
func (h *CommunityHandler) Follow(c *gin.Context) {
	var body struct {
		FollowingID int64 `json:"following_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供 following_id")
		return
	}
	uid := currentUserID(c)
	following, err := h.svc.Follow(c.Request.Context(), uid, body.FollowingID)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, gin.H{"following": following})
}

// ShareToCommunity 将分析报告分享为社区帖 POST /api/community/share-report （需家长认证）
func (h *CommunityHandler) ShareToCommunity(c *gin.Context) {
	var body struct {
		PaperID int64  `json:"paper_id" binding:"required"`
		CircleID int64 `json:"circle_id" binding:"required"`
		Comment  string `json:"comment"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供 paper_id 与 circle_id")
		return
	}
	uid := currentUserID(c)
	post, err := h.svc.ShareToCommunity(c.Request.Context(), uid, body.PaperID, body.CircleID, body.Comment)
	if err != nil {
		mapErr(c, err)
		return
	}
	Created(c, post)
}

// ReviewPost 后台审核帖子 POST /api/admin/posts/review
func (h *CommunityHandler) ReviewPost(c *gin.Context) {
	var body struct {
		PostID  int64  `json:"post_id" binding:"required"`
		Approve bool   `json:"approve"`
		Note    string `json:"note"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请提供 post_id")
		return
	}
	reviewer := currentUserID(c)
	post, err := h.svc.ReviewPost(c.Request.Context(), body.PostID, reviewer, body.Approve, body.Note)
	if err != nil {
		mapErr(c, err)
		return
	}
	OK(c, post)
}
