package service

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"time"

	"github.com/peidu-community/backend/internal/model"
	"gorm.io/gorm"
)

// InviteService 邀请码业务（轻量认证 + 拉新）
type InviteService struct {
	deps *Deps
}

// NewInviteService 构造邀请码服务
func NewInviteService(deps *Deps) *InviteService {
	return &InviteService{deps: deps}
}

func randCode(n int) string {
	const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	b := make([]byte, n)
	for i := range b {
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		b[i] = chars[idx.Int64()]
	}
	return string(b)
}

// Generate 生成邀请码（默认 3 次可用，30 天有效）
func (s *InviteService) Generate(ctx context.Context, inviterID int64) (*model.InviteCode, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	code := randCode(6)
	ic := model.InviteCode{
		Code:      code,
		InviterID: inviterID,
		MaxUses:   3,
		UsedCount: 0,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour),
	}
	if err = db.Create(&ic).Error; err != nil {
		return nil, err
	}
	s.deps.Tracker.Track("invite_generate", inviterID, map[string]interface{}{"code": code})
	return &ic, nil
}

// List 列出用户生成的邀请码
func (s *InviteService) List(ctx context.Context, inviterID int64) ([]model.InviteCode, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var list []model.InviteCode
	if err = db.Where("inviter_id = ?", inviterID).Order("created_at desc").Find(&list).Error; err != nil {
		return nil, err
	}
	return list, nil
}

// Use 使用邀请码：校验有效性 -> 将使用者标记为已认证家长（邀请码即轻量认证）
func (s *InviteService) Use(ctx context.Context, userID int64, code string) (*model.AuthVerification, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var ic model.InviteCode
	if err = db.Where("code = ?", code).First(&ic).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, fmt.Errorf("邀请码不存在")
		}
		return nil, err
	}
	if time.Now().After(ic.ExpiresAt) {
		return nil, fmt.Errorf("邀请码已过期")
	}
	if ic.UsedCount >= ic.MaxUses {
		return nil, fmt.Errorf("邀请码已达使用上限")
	}

	// 使用者直接通过邀请码完成家长认证
	now := time.Now()
	av := model.AuthVerification{
		UserID:     userID,
		Method:     "invite_code",
		InviteCode: code,
		Status:     "approved",
		ReviewNote: "邀请码自动认证",
		ReviewedAt: &now,
	}
	if err = db.Create(&av).Error; err != nil {
		return nil, err
	}
	if err = db.Model(&model.User{}).Where("id = ?", userID).Updates(map[string]interface{}{
		"role":        "parent",
		"verified_at": now,
	}).Error; err != nil {
		return nil, err
	}
	// 邀请码用量 +1，并奖励邀请人 1 次分析额度
	ic.UsedCount++
	db.Save(&ic)
	s.deps.AddBonusQuota(ctx, ic.InviterID, 1)

	s.deps.Tracker.Track("invite_used", userID, map[string]interface{}{"code": code, "inviter_id": ic.InviterID})
	return &av, nil
}
