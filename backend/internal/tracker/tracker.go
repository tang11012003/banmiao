package tracker

import (
	"encoding/json"
	"log"
	"time"
)

// Event 埋点事件结构（结构化日志）
type Event struct {
	Name      string                 `json:"event"`
	UserID    int64                  `json:"user_id"`
	Timestamp time.Time              `json:"ts"`
	Params    map[string]interface{} `json:"params"`
}

// Tracker 轻量埋点占位实现：仅打印结构化日志。
// 后续可替换为 Kafka / 消息队列上报，接口保持不变。
type Tracker struct{}

// New 创建 Tracker 实例
func New() *Tracker {
	return &Tracker{}
}

// Track 上报一个埋点事件，事件名对齐 PRD 第十章埋点清单。
func (t *Tracker) Track(event string, userID int64, params map[string]interface{}) {
	if params == nil {
		params = map[string]interface{}{}
	}
	e := Event{
		Name:      event,
		UserID:    userID,
		Timestamp: time.Now(),
		Params:    params,
	}
	b, err := json.Marshal(e)
	if err != nil {
		log.Printf("[TRACK] marshal error: %v", err)
		return
	}
	log.Printf("[TRACK] %s", string(b))
}
