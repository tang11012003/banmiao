package service

import (
	"context"
	"fmt"
	"time"

	"github.com/peidu-community/backend/internal/model"
	"gorm.io/gorm"
)

// CalendarTemplate 高考日历官方节点模板（相对高考日的月份偏移）
type CalendarTemplate struct {
	Name      string `json:"name"`
	EventType string `json:"event_type"`
	MonthOff  int    `json:"month_off"` // 相对高考日的月份偏移（负数表示之前）
	Desc      string `json:"desc"`
}

// officialTemplates 官方关键节点（静态模板，便于一键添加）
var officialTemplates = []CalendarTemplate{
	{"高考报名", "registration", -7, "各省高考网上报名"},
	{"艺术类统考", "gaokao", -6, "艺术类专业省统考"},
	{"一模考试", "mock_exam", -4, "高三第一次模拟考"},
	{"体育统考", "physical_exam", -3, "体育类专业省统考"},
	{"二模考试", "mock_exam", -2, "高三第二次模拟考"},
	{"外语口试", "oral_exam", -1, "高考外语口试"},
	{"高考", "gaokao", 0, "全国统一高考"},
	{"志愿填报", "volunteer", 1, "高考成绩公布与志愿填报"},
}

// CalendarService 高考日历相关业务
type CalendarService struct {
	deps *Deps
}

// NewCalendarService 构造日历服务
func NewCalendarService(deps *Deps) *CalendarService {
	return &CalendarService{deps: deps}
}

// Countdown 距离高考还有多少天
func (s *CalendarService) Countdown() (int, string, error) {
	layout := "2006-01-02"
	t, err := time.Parse(layout, s.deps.Cfg.App.GaokaoDate)
	if err != nil {
		return 0, "", fmt.Errorf("高考日期配置错误: %w", err)
	}
	days := int(time.Until(t).Hours() / 24)
	return days, s.deps.Cfg.App.GaokaoDate, nil
}

// Templates 返回官方节点模板
func (s *CalendarService) Templates() []CalendarTemplate {
	return officialTemplates
}

// ListEvents 列出用户日历事件（可按学生过滤）
func (s *CalendarService) ListEvents(ctx context.Context, userID, studentID int64) ([]model.CalendarEvent, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	q := db.Where("user_id = ?", userID)
	if studentID > 0 {
		q = q.Where("student_id = ?", studentID)
	}
	var events []model.CalendarEvent
	if err = q.Order("event_date asc").Find(&events).Error; err != nil {
		return nil, err
	}
	// 体验态：未指定学生且当前用户无任何日程时，自动灌入样例数据（幂等）
	if studentID == 0 && len(events) == 0 {
		if serr := s.seedSampleEvents(ctx, db, userID); serr == nil {
			var seeded []model.CalendarEvent
			if ferr := db.Where("user_id = ?", userID).Order("event_date asc").Find(&seeded).Error; ferr == nil {
				events = seeded
			}
		}
	}
	return events, nil
}

// seedSampleEvents 为体验账号灌入样例日程：覆盖“临近今天 + 整个高三学年 + 高考后”的真实关键节点，
// 便于日历月视图一打开就有内容、可读性更高。
func (s *CalendarService) seedSampleEvents(ctx context.Context, db *gorm.DB, userID int64) error {
	now := time.Now()
	gk, _ := time.Parse("2006-01-02", s.deps.Cfg.App.GaokaoDate)
	type sample struct {
		title       string
		typ         string
		subject     string
		daysFromNow int   // >0 表示相对今天；0 表示改用 daysFromGk
		daysFromGk  *int  // 相对高考日的偏移（负数=考前）
	}
	intp := func(v int) *int { return &v }
	samples := []sample{
		// 临近“今天”的暑期安排
		{"暑假规划家长会", "custom", "", 8, nil},
		{"高三暑假集训开营", "custom", "", 24, nil},
		// 高三学年关键节点（相对高考日 2027-06-07）
		{"高三开学典礼", "custom", "", 0, intp(-279)},
		{"第一次月考", "mock_exam", "数学", 0, intp(-255)},
		{"国庆假期", "custom", "", 0, intp(-249)},
		{"第二次月考", "mock_exam", "英语", 0, intp(-230)},
		{"期中考试", "custom", "", 0, intp(-204)},
		{"期中家长会", "custom", "", 0, intp(-199)},
		{"第三次月考", "mock_exam", "物理", 0, intp(-179)},
		{"一模考试", "mock_exam", "全科", 0, intp(-148)},
		{"一模考后分析会", "custom", "", 0, intp(-146)}, // 与“一模”同日，演示“同日多件事”
		{"寒假开始", "custom", "", 0, intp(-138)},
		{"二轮复习启动", "custom", "", 0, intp(-107)},
		{"百日誓师", "custom", "", 0, intp(-100)},
		{"二模考试", "mock_exam", "全科", 0, intp(-84)},
		{"体育统考", "physical_exam", "", 0, intp(-58)},
		{"三模考试", "mock_exam", "全科", 0, intp(-43)},
		{"外语口试", "oral_exam", "", 0, intp(-18)},
		{"看考场 / 考前注意事项", "custom", "", 0, intp(-1)}, // 与“高考”前一日，演示“同日多件事”
		{"高考", "gaokao", "", 0, intp(0)},
		{"高考成绩公布", "custom", "", 0, intp(18)},
		{"志愿填报", "volunteer", "", 0, intp(21)},
		{"录取通知书", "custom", "", 0, intp(43)},
	}
	events := make([]model.CalendarEvent, 0, len(samples))
	for _, sm := range samples {
		var d time.Time
		switch {
		case sm.daysFromNow > 0:
			d = now.AddDate(0, 0, sm.daysFromNow)
		case sm.daysFromGk != nil && !gk.IsZero():
			d = gk.AddDate(0, 0, *sm.daysFromGk)
		default:
			d = now
		}
		events = append(events, model.CalendarEvent{
			UserID:    userID,
			Title:     sm.title,
			Event:     sm.typ,
			EventDate: d,
			Subject:   sm.subject,
		})
	}
	if err := db.Create(&events).Error; err != nil {
		return err
	}
	s.deps.Tracker.Track("calendar_sample_seed", userID, map[string]interface{}{"count": len(events)})
	return nil
}

// CreateEventInput 创建日历事件入参
type CreateEventInput struct {
	StudentID      int64  `json:"student_id"`
	Title          string `json:"title" binding:"required"`
	EventType      string `json:"event_type"`
	EventDate      string `json:"event_date" binding:"required"` // 2006-01-02
	Subject        string `json:"subject"`
	ReminderBefore int    `json:"reminder_before"`
}

// CreateEvent 创建日历事件
func (s *CalendarService) CreateEvent(ctx context.Context, userID int64, in CreateEventInput) (*model.CalendarEvent, error) {
	t, err := time.Parse("2006-01-02", in.EventDate)
	if err != nil {
		return nil, fmt.Errorf("日期格式应为 2006-01-02")
	}
	ev := model.CalendarEvent{
		UserID:         userID,
		StudentID:      nilIfZero(in.StudentID),
		Title:          in.Title,
		Event:          in.EventType,
		EventDate:      t,
		Subject:        in.Subject,
		ReminderBefore: in.ReminderBefore,
	}
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	if err = db.Create(&ev).Error; err != nil {
		return nil, err
	}
	s.deps.Tracker.Track("calendar_event_create", userID, map[string]interface{}{"event_type": in.EventType})
	return &ev, nil
}

// RecordExamInput 记录模拟考入参
type RecordExamInput struct {
	StudentID int64   `json:"student_id" binding:"required"`
	Name       string  `json:"name" binding:"required"`
	Subject    string  `json:"subject" binding:"required"`
	ExamDate   string  `json:"exam_date" binding:"required"`
	TotalScore float64 `json:"total_score"`
	ScoredRate float64 `json:"scored_rate"`
}

// RecordExam 记录一次模拟考成绩
func (s *CalendarService) RecordExam(ctx context.Context, userID int64, in RecordExamInput) (*model.Exam, error) {
	t, err := time.Parse("2006-01-02", in.ExamDate)
	if err != nil {
		return nil, fmt.Errorf("日期格式应为 2006-01-02")
	}
	exam := model.Exam{
		UserID:     userID,
		StudentID:  in.StudentID,
		Name:       in.Name,
		Subject:    in.Subject,
		ExamDate:   t,
		TotalScore: in.TotalScore,
		ScoredRate: in.ScoredRate,
	}
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	if err = db.Create(&exam).Error; err != nil {
		return nil, err
	}
	s.deps.Tracker.Track("exam_record", userID, map[string]interface{}{"subject": in.Subject, "name": in.Name})
	return &exam, nil
}

func nilIfZero(v int64) *int64 {
	if v == 0 {
		return nil
	}
	return &v
}
