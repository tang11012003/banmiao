package service

import (
	"context"
	"time"

	"github.com/peidu-community/backend/internal/model"
	"gorm.io/gorm"
)

// NotificationService 消息/通知业务
type NotificationService struct {
	deps *Deps
}

// NewNotificationService 构造通知服务
func NewNotificationService(deps *Deps) *NotificationService {
	return &NotificationService{deps: deps}
}

// List 列出当前用户通知（按时间倒序），无数据时幂等预置体验样例。
func (s *NotificationService) List(ctx context.Context, userID int64) ([]model.Notification, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var list []model.Notification
	if err = db.Where("user_id = ?", userID).Order("is_read asc, created_at desc").Find(&list).Error; err != nil {
		return nil, err
	}
	if len(list) == 0 {
		s.seedSample(db, userID)
		if err = db.Where("user_id = ?", userID).Order("is_read asc, created_at desc").Find(&list).Error; err != nil {
			return nil, err
		}
	}
	return list, nil
}

// MarkRead 标记单条/全部已读（id<=0 时标记全部）。
func (s *NotificationService) MarkRead(ctx context.Context, userID, id int64) error {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return err
	}
	q := db.Model(&model.Notification{}).Where("user_id = ?", userID)
	if id > 0 {
		q = q.Where("id = ?", id)
	}
	return q.UpdateColumn("is_read", true).Error
}

// seedSample 预置体验通知（社区互动 + 系统）。
func (s *NotificationService) seedSample(db *gorm.DB, userID int64) {
	now := time.Now()
	samples := []model.Notification{
		{UserID: userID, Type: "comment", Title: "有人回复了你的帖子", Content: "《一模数学怎么追》下有 3 条新回复，快去看看～", IsRead: false, CreatedAt: now.Add(-2 * time.Hour)},
		{UserID: userID, Type: "like", Title: "你的帖子被点有用", Content: "《高三最后一年如何不焦虑》获得 12 个「有用」", IsRead: false, CreatedAt: now.Add(-20 * time.Hour)},
		{UserID: userID, Type: "follow", Title: "有新家长关注了你", Content: "「海淀虎妈」关注了你，互相关注认识一下？", IsRead: true, CreatedAt: now.Add(-48 * time.Hour)},
		{UserID: userID, Type: "system", Title: "欢迎使用陪读社区", Content: "完成家长认证后即可上传试卷、发帖互动，与百万陪读家长同行。", IsRead: true, CreatedAt: now.Add(-72 * time.Hour)},
	}
	db.Create(&samples)
}
