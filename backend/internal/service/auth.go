package service

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/peidu-community/backend/internal/middleware"
	"github.com/peidu-community/backend/internal/model"
	"gorm.io/gorm"
)

// smsCode 短信验证码（开发态内存存储，生产应替换为 Redis）
type smsCode struct {
	code      string
	expireAt  time.Time
}

var (
	smsStore   = map[string]smsCode{}
	smsMutex   sync.Mutex
	smsValidity = 5 * time.Minute
)

// AuthService 认证与家长认证相关业务
type AuthService struct {
	deps *Deps
}

// NewAuthService 构造认证服务
func NewAuthService(deps *Deps) *AuthService {
	return &AuthService{deps: deps}
}

func genCode() string {
	n, _ := rand.Int(rand.Reader, big.NewInt(1000000))
	return fmt.Sprintf("%06d", n.Int64())
}

// SendSMS 发送登录短信验证码（开发态直接返回验证码便于联调）
func (s *AuthService) SendSMS(ctx context.Context, phone string) (string, error) {
	if len(phone) != 11 {
		return "", fmt.Errorf("手机号格式不正确")
	}
	code := genCode()
	smsMutex.Lock()
	smsStore[phone] = smsCode{code: code, expireAt: time.Now().Add(smsValidity)}
	smsMutex.Unlock()
	return code, nil
}

// Login 校验短信验证码并登录，返回 JWT 与用户信息
func (s *AuthService) Login(ctx context.Context, phone, code string) (string, *model.User, error) {
	// 万能验证码：开发态任何手机号输入 888888 直接通过
	if code != "888888" {
		smsMutex.Lock()
		stored, ok := smsStore[phone]
		delete(smsStore, phone)
		smsMutex.Unlock()
		if !ok || stored.code != code {
			return "", nil, fmt.Errorf("验证码错误或已失效")
		}
		if time.Now().After(stored.expireAt) {
			return "", nil, fmt.Errorf("验证码已过期")
		}
	}

	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return "", nil, err
	}
	var user model.User
	err = db.Where("phone = ?", phone).FirstOrCreate(&user, model.User{Phone: phone, Nickname: "家长" + phone[len(phone)-4:]}).Error
	if err != nil {
		return "", nil, err
	}

	token, err := middleware.GenerateJWT(user.ID, user.Phone, user.Role, s.deps.Cfg.JWT.Secret, s.deps.Cfg.JWT.Expiration)
	if err != nil {
		return "", nil, err
	}
	return token, &user, nil
}

// GetProfile 获取当前用户资料
func (s *AuthService) GetProfile(ctx context.Context, userID int64) (*model.User, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var user model.User
	if err = db.First(&user, userID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &user, nil
}

// SubmitVerification 提交家长认证申请（4 种方式之一，或邀请码）
func (s *AuthService) SubmitVerification(ctx context.Context, userID int64, method, materialImage, inviteCode string) (*model.AuthVerification, error) {
	valid := map[string]bool{"student_card": true, "class_group": true, "payment": true, "invite_code": true}
	if !valid[method] {
		return nil, fmt.Errorf("不支持的认证方式: %s", method)
	}
	if method == "invite_code" && inviteCode == "" {
		return nil, fmt.Errorf("邀请码认证方式需提供邀请码")
	}
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	av := model.AuthVerification{
		UserID:        userID,
		Method:        method,
		MaterialImage: materialImage,
		InviteCode:    inviteCode,
		Status:        "pending",
	}
	if err = db.Create(&av).Error; err != nil {
		return nil, err
	}
	s.deps.Tracker.Track("verification_submit", userID, map[string]interface{}{"method": method})
	return &av, nil
}

// GetVerificationStatus 获取最新一条认证申请状态
func (s *AuthService) GetVerificationStatus(ctx context.Context, userID int64) (*model.AuthVerification, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var av model.AuthVerification
	err = db.Where("user_id = ?", userID).Order("created_at desc").First(&av).Error
	if err == gorm.ErrRecordNotFound {
		return nil, nil // 尚未提交
	}
	if err != nil {
		return nil, err
	}
	return &av, nil
}

// ReviewVerification 后台人工审核认证申请（模拟）
func (s *AuthService) ReviewVerification(ctx context.Context, verificationID, reviewerID int64, approve bool, note string) (*model.AuthVerification, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var av model.AuthVerification
	if err = db.First(&av, verificationID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if approve {
		av.Status = "approved"
		av.ReviewNote = note
		now := time.Now()
		av.ReviewedAt = &now
		av.ReviewerID = &reviewerID
		// 审核通过 -> 用户升级为已认证家长
		if e := db.Model(&model.User{}).Where("id = ?", av.UserID).Updates(map[string]interface{}{
			"role":        "parent",
			"verified_at": now,
		}).Error; e != nil {
			return nil, e
		}
	} else {
		av.Status = "rejected"
		av.ReviewNote = note
		now := time.Now()
		av.ReviewedAt = &now
		av.ReviewerID = &reviewerID
	}
	if err = db.Save(&av).Error; err != nil {
		return nil, err
	}
	s.deps.Tracker.Track("verification_review", reviewerID, map[string]interface{}{
		"verification_id": verificationID, "approve": approve,
	})
	return &av, nil
}

// RemainingQuota 返回用户当月剩余免费与奖励分析次数
func (s *AuthService) RemainingQuota(ctx context.Context, userID int64) (freeRemain, bonusRemain int, err error) {
	return s.deps.RemainingQuota(ctx, userID)
}
