package service

import (
	"context"
	"time"

	"github.com/peidu-community/backend/internal/config"
	"github.com/peidu-community/backend/internal/ocr"
	"github.com/peidu-community/backend/internal/tracker"
	"gorm.io/gorm"
)

// Deps 是所有 service 共享的依赖集合
type Deps struct {
	DB      *gorm.DB
	OCR     *ocr.Client
	Cfg     *config.Config
	Tracker *tracker.Tracker
}

// NewDeps 构造依赖集合
func NewDeps(db *gorm.DB, cfg *config.Config, tk *tracker.Tracker) *Deps {
	return &Deps{
		DB:      db,
		OCR:     ocr.NewClient(cfg.OCR.BaseURL),
		Cfg:     cfg,
		Tracker: tk,
	}
}

// YearMonth 返回当前年月字符串，格式 2025-07
func YearMonth(t time.Time) string {
	return t.Format("2006-01")
}

// MatchLevel 三档判定：错误率 >=50% 待改进(urgent)，20%~49% 需关注(attention)，<20% 继续保持(keep)
func MatchLevel(errorRate float64) string {
	switch {
	case errorRate >= 0.5:
		return "urgent"
	case errorRate >= 0.2:
		return "attention"
	default:
		return "keep"
	}
}

// LevelLabel 三档中文标签
func LevelLabel(level string) string {
	switch level {
	case "urgent":
		return "待改进"
	case "attention":
		return "需关注"
	case "keep":
		return "继续保持"
	default:
		return level
	}
}

// dbOrErr 当数据库不可用时返回统一错误，避免 nil 指针
func (d *Deps) dbOrErr() (*gorm.DB, error) {
	if d.DB == nil {
		return nil, ErrDBUnavailable
	}
	return d.DB, nil
}

// ctxDB 带 context 的 db 句柄
func (d *Deps) ctxDB(ctx context.Context) (*gorm.DB, error) {
	db, err := d.dbOrErr()
	if err != nil {
		return nil, err
	}
	return db.WithContext(ctx), nil
}
