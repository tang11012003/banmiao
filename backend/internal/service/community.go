package service

import (
	"context"
	"fmt"
	"time"

	"github.com/peidu-community/backend/internal/model"
	"gorm.io/gorm"
)

// CommunityService 陪读社区业务
type CommunityService struct {
	deps *Deps
}

// NewCommunityService 构造社区服务
func NewCommunityService(deps *Deps) *CommunityService {
	return &CommunityService{deps: deps}
}

// ListCircles 列出全部圈子（供前端选择发布圈子）
func (s *CommunityService) ListCircles(ctx context.Context) ([]model.CommunityCircle, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var circles []model.CommunityCircle
	if err = db.Order("id asc").Find(&circles).Error; err != nil {
		return nil, err
	}
	return circles, nil
}

// ListPosts 列出已发布帖子（可按圈子过滤，按时间倒序）
func (s *CommunityService) ListPosts(ctx context.Context, circleID, limit, offset int) ([]model.CommunityPost, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	q := db.Where("status = ?", "published")
	if circleID > 0 {
		q = q.Where("circle_id = ?", circleID)
	}
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	var posts []model.CommunityPost
	if err = q.Order("is_pinned desc, created_at desc").Limit(limit).Offset(offset).Find(&posts).Error; err != nil {
		return nil, err
	}
	return posts, nil
}

// GetPost 获取帖子详情
func (s *CommunityService) GetPost(ctx context.Context, postID int64) (*model.CommunityPost, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var post model.CommunityPost
	if err = db.First(&post, postID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &post, nil
}

// CreatePostInput 发帖入参
type CreatePostInput struct {
	CircleID   int64    `json:"circle_id" binding:"required"`
	Title      string   `json:"title"`
	Content    string   `json:"content" binding:"required"`
	Images     []string `json:"images"`
	ParentPostID int64   `json:"parent_post_id"` // 引用/转发源帖
}

// CreatePost 发布帖子（默认已发布，保留后台审核能力）
func (s *CommunityService) CreatePost(ctx context.Context, userID int64, in CreatePostInput) (*model.CommunityPost, error) {
	post := model.CommunityPost{
		UserID:      userID,
		CircleID:    in.CircleID,
		Title:       in.Title,
		Content:     in.Content,
		ContentType: "text",
		Images:      in.Images,
		Status:      "published",
	}
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	if err = db.Create(&post).Error; err != nil {
		return nil, err
	}
	// 圈子帖子数 +1
	db.Model(&model.CommunityCircle{}).Where("id = ?", in.CircleID).UpdateColumn("post_count", gorm.Expr("post_count + 1"))
	s.deps.Tracker.Track("post_create", userID, map[string]interface{}{"post_id": post.ID, "circle_id": in.CircleID})
	return &post, nil
}

// Comment 评论（支持嵌套，可带图片）
func (s *CommunityService) Comment(ctx context.Context, userID, postID int64, content string, parentID int64, image string) (*model.CommunityComment, error) {
	if content == "" && image == "" {
		return nil, fmt.Errorf("评论内容不能为空")
	}
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	cm := model.CommunityComment{
		PostID:   postID,
		UserID:   userID,
		ParentID: nilIfZero(parentID),
		Content:  content,
		Image:    image,
		Status:   "published",
	}
	if err = db.Create(&cm).Error; err != nil {
		return nil, err
	}
	db.Model(&model.CommunityPost{}).Where("id = ?", postID).UpdateColumn("comment_count", gorm.Expr("comment_count + 1"))
	s.deps.Tracker.Track("post_comment", userID, map[string]interface{}{"post_id": postID})
	return &cm, nil
}

// ListComments 列出帖子评论
func (s *CommunityService) ListComments(ctx context.Context, postID int64) ([]model.CommunityComment, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var comments []model.CommunityComment
	if err = db.Where("post_id = ? AND status = ?", postID, "published").Order("created_at asc").Find(&comments).Error; err != nil {
		return nil, err
	}
	return comments, nil
}

// Like 点赞/取消点赞（切换）
func (s *CommunityService) Like(ctx context.Context, userID int64, targetType string, targetID int64) (liked bool, err error) {
	if targetType != "post" && targetType != "comment" {
		return false, fmt.Errorf("不支持的点赞对象")
	}
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return false, err
	}
	var existing model.CommunityLike
	err = db.Where("user_id = ? AND target_type = ? AND target_id = ?", userID, targetType, targetID).First(&existing).Error
	if err == nil {
		// 已赞 -> 取消
		db.Delete(&existing)
		s.decCount(db, targetType, targetID, "like_count")
		return false, nil
	}
	if err != gorm.ErrRecordNotFound {
		return false, err
	}
	// 未赞 -> 点赞
	like := model.CommunityLike{UserID: userID, TargetType: targetType, TargetID: targetID}
	if err = db.Create(&like).Error; err != nil {
		return false, err
	}
	s.incCount(db, targetType, targetID, "like_count")
	return true, nil
}

func (s *CommunityService) incCount(db *gorm.DB, targetType string, targetID int64, col string) {
	table := "community_posts"
	if targetType == "comment" {
		table = "community_comments"
	}
	db.Table(table).Where("id = ?", targetID).UpdateColumn(col, gorm.Expr(col+" + 1"))
}

func (s *CommunityService) decCount(db *gorm.DB, targetType string, targetID int64, col string) {
	table := "community_posts"
	if targetType == "comment" {
		table = "community_comments"
	}
	db.Table(table).Where("id = ?", targetID).UpdateColumn(col, gorm.Expr(col+" - 1"))
}

// Follow 关注/取关（切换）
func (s *CommunityService) Follow(ctx context.Context, followerID, followingID int64) (following bool, err error) {
	if followerID == followingID {
		return false, fmt.Errorf("不能关注自己")
	}
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return false, err
	}
	var existing model.Follow
	err = db.Where("follower_id = ? AND following_id = ?", followerID, followingID).First(&existing).Error
	if err == nil {
		db.Delete(&existing)
		return false, nil
	}
	if err != gorm.ErrRecordNotFound {
		return false, err
	}
	f := model.Follow{FollowerID: followerID, FollowingID: followingID}
	if err = db.Create(&f).Error; err != nil {
		return false, err
	}
	s.deps.Tracker.Track("user_follow", followerID, map[string]interface{}{"following_id": followingID})
	return true, nil
}

// ShareToCommunity 将试卷分析报告分享为社区帖子（工具结果可分享到社区）
func (s *CommunityService) ShareToCommunity(ctx context.Context, userID, paperID, circleID int64, comment string) (*model.CommunityPost, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var paper model.Paper
	if err = db.First(&paper, paperID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if paper.UserID != userID {
		return nil, ErrNotVerified
	}
	content := comment
	if content == "" {
		content = "分享了一份试卷分析报告，欢迎交流～"
	}
	post := model.CommunityPost{
		UserID:      userID,
		CircleID:    circleID,
		Title:       "试卷分析报告",
		Content:     content,
		ContentType: "share_report",
		Status:      "published",
		ReportRefID: paper.ExamID,
	}
	if err = db.Create(&post).Error; err != nil {
		return nil, err
	}
	db.Model(&model.CommunityCircle{}).Where("id = ?", circleID).UpdateColumn("post_count", gorm.Expr("post_count + 1"))
	// 工具分享到社区也算一次分享，赠送奖励次数
	if err = s.deps.AddBonusQuota(ctx, userID, 1); err != nil {
		return nil, err
	}
	s.deps.Tracker.Track("share_to_community", userID, map[string]interface{}{"post_id": post.ID, "paper_id": paperID})
	s.deps.Tracker.Track("invite_used", userID, map[string]interface{}{"source": "share_report"})
	return &post, nil
}

// ReviewPost 后台审核帖子（发布/驳回）
func (s *CommunityService) ReviewPost(ctx context.Context, postID, reviewerID int64, approve bool, note string) (*model.CommunityPost, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var post model.CommunityPost
	if err = db.First(&post, postID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	now := time.Now()
	if approve {
		post.Status = "published"
	} else {
		post.Status = "rejected"
	}
	post.ReviewNote = note
	post.ReviewerID = &reviewerID
	post.ReviewedAt = &now
	if err = db.Save(&post).Error; err != nil {
		return nil, err
	}
	s.deps.Tracker.Track("post_review", reviewerID, map[string]interface{}{"post_id": postID, "approve": approve})
	return &post, nil
}
