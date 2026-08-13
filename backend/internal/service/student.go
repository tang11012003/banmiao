package service

import (
	"context"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/peidu-community/backend/internal/model"
)

// StudentService 学生（孩子）相关服务。
type StudentService struct {
	deps *Deps
}

// NewStudentService 构造学生服务。
func NewStudentService(deps *Deps) *StudentService {
	return &StudentService{deps: deps}
}

// StudentView 学生视图（含派生信息，便于前端构建切换器）。
type StudentView struct {
	ID            int64    `json:"id"`
	Name          string   `json:"name"`
	Grade         string   `json:"grade"`
	ExamType      string   `json:"exam_type"`
	Subjects      []string `json:"subjects"`       // 有考试记录的科目（升序）
	AcademicYears []string `json:"academic_years"` // 9 月开学制学年标签，如 ["2024-2025","2025-2026"]
}

// List 返回当前用户的学生列表（含派生科目与学年）。
func (s *StudentService) List(ctx context.Context, userID int64) ([]StudentView, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var students []model.Student
	if err = db.Where("user_id = ?", userID).Order("id asc").Find(&students).Error; err != nil {
		return nil, err
	}
	views := make([]StudentView, 0, len(students))
	for _, st := range students {
		v := StudentView{
			ID:       st.ID,
			Name:     st.Name,
			Grade:    st.Grade,
			ExamType: st.ExamType,
		}
		var exams []model.Exam
		db.Where("student_id = ?", st.ID).Order("exam_date asc").Find(&exams)
		subjSet := map[string]bool{}
		yearSet := map[string]bool{}
		for _, e := range exams {
			if e.Subject != "" {
				subjSet[e.Subject] = true
			}
			if y := AcademicYearLabel(e.ExamDate); y != "" {
				yearSet[y] = true
			}
		}
		for s2 := range subjSet {
			v.Subjects = append(v.Subjects, s2)
		}
		for y := range yearSet {
			v.AcademicYears = append(v.AcademicYears, y)
		}
		sort.Strings(v.Subjects)
		sort.Strings(v.AcademicYears)
		views = append(views, v)
	}
	return views, nil
}

// AcademicYearLabel 9 月开学制学年标签：2024-2025 表示 2024-09-01~2025-08-31。
func AcademicYearLabel(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	y := t.Year()
	start := y
	if t.Month() < 9 {
		start = y - 1
	}
	return fmt.Sprintf("%d-%d", start, start+1)
}

// academicYearRange 将学年标签解析为起止时间（含边界），用于按考试日期过滤。
func academicYearRange(label string) (time.Time, time.Time, bool) {
	parts := strings.Split(label, "-")
	if len(parts) != 2 {
		return time.Time{}, time.Time{}, false
	}
	start, err1 := strconv.Atoi(parts[0])
	end, err2 := strconv.Atoi(parts[1])
	if err1 != nil || err2 != nil || end != start+1 {
		return time.Time{}, time.Time{}, false
	}
	lo := time.Date(start, 9, 1, 0, 0, 0, 0, time.Local)
	hi := time.Date(end, 8, 31, 23, 59, 59, 0, time.Local)
	return lo, hi, true
}
