package service

import (
	"context"
	"time"

	"github.com/peidu-community/backend/internal/model"
)

const freeQuotaPerMonth = 3

// getOrCreateQuota 获取或创建用户当月配额记录
func (d *Deps) getOrCreateQuota(ctx context.Context, userID int64) (*model.AnalysisQuota, error) {
	db, err := d.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	ym := YearMonth(time.Now())
	var q model.AnalysisQuota
	err = db.Where("user_id = ? AND year_month = ?", userID, ym).FirstOrCreate(&q, model.AnalysisQuota{
		UserID:    userID,
		YearMonth: ym,
		FreeQuota: freeQuotaPerMonth,
	}).Error
	if err != nil {
		return nil, err
	}
	return &q, nil
}

// RemainingQuota 返回用户当月剩余免费与奖励次数
func (d *Deps) RemainingQuota(ctx context.Context, userID int64) (freeRemain, bonusRemain int, err error) {
	q, err := d.getOrCreateQuota(ctx, userID)
	if err != nil {
		return 0, 0, err
	}
	return q.FreeQuota - q.FreeUsed, q.BonusQuota - q.BonusUsed, nil
}

// ConsumeQuota 消费一次分析次数（优先免费，其次奖励），不足返回 ErrQuotaExhausted
func (d *Deps) ConsumeQuota(ctx context.Context, userID int64) error {
	q, err := d.getOrCreateQuota(ctx, userID)
	if err != nil {
		return err
	}
	updates := map[string]interface{}{}
	now := time.Now()
	if q.FreeUsed < q.FreeQuota {
		q.FreeUsed++
		updates["free_used"] = q.FreeUsed
	} else if q.BonusUsed < q.BonusQuota {
		q.BonusUsed++
		updates["bonus_used"] = q.BonusUsed
	} else {
		return ErrQuotaExhausted
	}
	q.UpdatedAt = now
	updates["updated_at"] = now
	return d.DB.WithContext(ctx).Model(&model.AnalysisQuota{}).
		Where("user_id = ? AND year_month = ?", userID, q.YearMonth).Updates(updates).Error
}

// AddBonusQuota 增加奖励分析次数（分享成功后调用）
func (d *Deps) AddBonusQuota(ctx context.Context, userID int64, n int) error {
	q, err := d.getOrCreateQuota(ctx, userID)
	if err != nil {
		return err
	}
	q.BonusQuota += n
	q.UpdatedAt = time.Now()
	return d.DB.WithContext(ctx).Model(&model.AnalysisQuota{}).
		Where("user_id = ? AND year_month = ?", userID, q.YearMonth).
		Updates(map[string]interface{}{"bonus_quota": q.BonusQuota, "updated_at": q.UpdatedAt}).Error
}
