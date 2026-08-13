package service

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"time"

	"github.com/peidu-community/backend/internal/model"
	"github.com/peidu-community/backend/internal/ocr"
	"gorm.io/gorm"
)

// PaperService 试卷分析与知识点诊断
type PaperService struct {
	deps *Deps
}

// NewPaperService 构造试卷服务
func NewPaperService(deps *Deps) *PaperService {
	return &PaperService{deps: deps}
}

// Upload 上传试卷：OCR 识别对错 -> 知识点匹配 -> 三档判定聚合
func (s *PaperService) Upload(ctx context.Context, userID, studentID int64, subject, examName string, file multipart.File, filename string) (*model.Paper, error) {
	// 1. 配额检查（先校验，避免无效 OCR 消耗）
	freeRemain, bonusRemain, err := s.deps.RemainingQuota(ctx, userID)
	if err != nil {
		return nil, err
	}
	if freeRemain <= 0 && bonusRemain <= 0 {
		return nil, ErrQuotaExhausted
	}

	// 2. 调用 OCR 服务识别对错（消费文件流）
	res, err := s.deps.OCR.Analyze(ctx, file, filename)
	if err != nil {
		return nil, fmt.Errorf("OCR 识别失败: %w", err)
	}

	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}

	// 3. 持久化试卷与题目
	now := time.Now()
	paper := model.Paper{
		UserID:    userID,
		Pages:     maxInt(res.TotalQuestions, 1),
		OCRStatus: "processing",
	}
	_ = now
	if err = db.Create(&paper).Error; err != nil {
		return nil, err
	}

	exam := model.Exam{
		UserID:   userID,
		StudentID: studentID,
		Name:     orDefault(examName, filename),
		Subject:  subject,
		ExamDate: now,
		ScoredRate: res.ScoreRate * 100,
	}
	if err = db.Create(&exam).Error; err != nil {
		return nil, err
	}
	paper.ExamID = exam.ID

	items := make([]model.PaperItem, 0, len(res.Questions))
	for _, q := range res.Questions {
		items = append(items, model.PaperItem{
			PaperID:     paper.ID,
			QuestionNum: q.QuestionNum,
			Text:        q.Text,
			Status:      q.Status,
			MaxScore:    q.MaxScore,
			ActualScore: q.ActualScore,
		})
	}
	if len(items) > 0 {
		if err = db.Create(&items).Error; err != nil {
			return nil, err
		}
	}

	// 4. 知识点匹配与三档聚合
	if err = s.aggregateKnowledge(ctx, db, exam.ID, subject, items, res.Questions); err != nil {
		return nil, err
	}

	// 5. 消费配额
	if err = s.deps.ConsumeQuota(ctx, userID); err != nil {
		return nil, err
	}

	// 6. 标记完成
	completed := time.Now()
	paper.OCRStatus = "completed"
	paper.OCRCompletedAt = &completed
	if err = db.Save(&paper).Error; err != nil {
		return nil, err
	}

	s.deps.Tracker.Track("paper_upload", userID, map[string]interface{}{
		"paper_id": paper.ID, "subject": subject, "questions": len(items),
	})
	s.deps.Tracker.Track("paper_analyzed", userID, map[string]interface{}{
		"paper_id": paper.ID, "correct": res.CorrectCount, "wrong": res.WrongCount,
	})
	return &paper, nil
}

// ScanResult Phase1 扫描结果
type ScanResult struct {
	PaperID        int64          `json:"paper_id"`
	ImageURL       string         `json:"image_url"`
	TotalQuestions int            `json:"total_questions"`
	Questions      []ocr.Question `json:"questions"`
}

// Scan 上传试卷仅做 OCR 识别，不做知识点聚合（Phase 1）
func (s *PaperService) Scan(ctx context.Context, userID, studentID int64, subject, examName string, file multipart.File, filename string) (*ScanResult, error) {
	freeRemain, bonusRemain, err := s.deps.RemainingQuota(ctx, userID)
	if err != nil {
		return nil, err
	}
	if freeRemain <= 0 && bonusRemain <= 0 {
		return nil, ErrQuotaExhausted
	}

	// 保存图片到 uploads/ 目录
	imgFilename := fmt.Sprintf("paper_%d_%d.jpg", userID, time.Now().UnixMilli())
	imgPath := filepath.Join("uploads", imgFilename)
	dst, err := os.Create(imgPath)
	if err != nil {
		return nil, fmt.Errorf("保存图片失败: %w", err)
	}
	if _, err = io.Copy(dst, file); err != nil {
		dst.Close()
		return nil, fmt.Errorf("保存图片失败: %w", err)
	}
	dst.Close()

	// 重新打开文件给 OCR 用
	ocrFile, err := os.Open(imgPath)
	if err != nil {
		return nil, fmt.Errorf("读取图片失败: %w", err)
	}
	defer ocrFile.Close()

	res, err := s.deps.OCR.Analyze(ctx, ocrFile, filename)
	if err != nil {
		return nil, fmt.Errorf("OCR 识别失败: %w", err)
	}

	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}

	imageURL := "/api/uploads/" + imgFilename
	paper := model.Paper{
		UserID:    userID,
		Pages:     maxInt(res.TotalQuestions, 1),
		ImageURL:  imageURL,
		OCRStatus: "scanned",
	}
	if err = db.Create(&paper).Error; err != nil {
		return nil, err
	}

	items := make([]model.PaperItem, 0, len(res.Questions))
	for _, q := range res.Questions {
		items = append(items, model.PaperItem{
			PaperID:     paper.ID,
			QuestionNum: q.QuestionNum,
			Text:        q.Text,
			Status:      q.Status,
			MaxScore:    q.MaxScore,
			ActualScore: q.ActualScore,
		})
	}
	if len(items) > 0 {
		if err = db.Create(&items).Error; err != nil {
			return nil, err
		}
	}

	s.deps.Tracker.Track("paper_scan", userID, map[string]interface{}{
		"paper_id": paper.ID, "subject": subject, "questions": len(items),
	})

	return &ScanResult{
		PaperID:        paper.ID,
		ImageURL:       imageURL,
		TotalQuestions: res.TotalQuestions,
		Questions:      res.Questions,
	}, nil
}

// ConfirmItem 用户确认的题目状态
type ConfirmItem struct {
	QuestionNum int    `json:"question_num"`
	Status      string `json:"status"`
	IsNew       bool   `json:"is_new"`
}

// Confirm 确认错题并生成分析报告（Phase 2）
func (s *PaperService) Confirm(ctx context.Context, userID, paperID int64, subject, examName string, studentID int64, items []ConfirmItem) (*model.Paper, error) {
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
	if paper.OCRStatus != "scanned" && paper.OCRStatus != "completed" {
		return nil, fmt.Errorf("试卷状态异常: %s", paper.OCRStatus)
	}

	// 若二次修改，清除旧数据
	if paper.OCRStatus == "completed" && paper.ExamID > 0 {
		db.Where("exam_id = ?", paper.ExamID).Delete(&model.ExamKPResult{})
		db.Delete(&model.Exam{}, paper.ExamID)
		paper.ExamID = 0
	}

	// 更新 PaperItem 状态 + 插入新题
	for _, ci := range items {
		if ci.IsNew {
			newItem := model.PaperItem{
				PaperID:     paperID,
				QuestionNum: ci.QuestionNum,
				Status:      ci.Status,
			}
			db.Create(&newItem)
		} else {
			db.Model(&model.PaperItem{}).
				Where("paper_id = ? AND question_num = ?", paperID, ci.QuestionNum).
				Update("status", ci.Status)
		}
	}

	// 重新加载所有 items
	var paperItems []model.PaperItem
	db.Where("paper_id = ?", paperID).Order("question_num asc").Find(&paperItems)

	// 计算得分率
	var total, correct int
	for _, it := range paperItems {
		total++
		if it.Status == "correct" {
			correct++
		}
	}
	scoreRate := float64(0)
	if total > 0 {
		scoreRate = float64(correct) / float64(total) * 100
	}

	// 创建 Exam
	now := time.Now()
	exam := model.Exam{
		UserID:     userID,
		StudentID:  studentID,
		Name:       orDefault(examName, "试卷分析"),
		Subject:    subject,
		ExamDate:   now,
		ScoredRate: scoreRate,
	}
	if err = db.Create(&exam).Error; err != nil {
		return nil, err
	}
	paper.ExamID = exam.ID

	// 知识点聚合
	ocrQuestions := make([]ocr.Question, 0, len(paperItems))
	for _, it := range paperItems {
		ocrQuestions = append(ocrQuestions, ocr.Question{
			QuestionNum: it.QuestionNum,
			Text:        it.Text,
			Status:      it.Status,
			MaxScore:    it.MaxScore,
			ActualScore: it.ActualScore,
		})
	}
	if err = s.aggregateKnowledge(ctx, db, exam.ID, subject, paperItems, ocrQuestions); err != nil {
		return nil, err
	}

	// 消费配额（仅首次确认扣费）
	if paper.OCRStatus == "scanned" {
		if err = s.deps.ConsumeQuota(ctx, userID); err != nil {
			return nil, err
		}
	}

	// 标记完成
	completed := time.Now()
	paper.OCRStatus = "completed"
	paper.OCRCompletedAt = &completed
	if err = db.Save(&paper).Error; err != nil {
		return nil, err
	}

	s.deps.Tracker.Track("paper_confirmed", userID, map[string]interface{}{
		"paper_id": paper.ID, "subject": subject, "wrong_count": total - correct,
	})
	return &paper, nil
}

// aggregateKnowledge 对每道题做知识点匹配，按知识点聚合错误率并落库
func (s *PaperService) aggregateKnowledge(ctx context.Context, db *gorm.DB, examID int64, subject string, items []model.PaperItem, questions []ocr.Question) error {
	// 只对已作答题目做匹配
	type pair struct {
		item model.PaperItem
		q    ocr.Question
	}
	valid := make([]pair, 0, len(items))
	for i, it := range items {
		if i >= len(questions) {
			break
		}
		if it.Text == "" {
			continue
		}
		if it.Status == "unanswered" {
			continue
		}
		valid = append(valid, pair{item: it, q: questions[i]})
	}
	if len(valid) == 0 {
		return nil
	}

	texts := make([]string, 0, len(valid))
	for _, p := range valid {
		texts = append(texts, p.item.Text)
	}
	batch, err := s.deps.OCR.BatchMatch(ctx, texts, subject, 3, 0.1)
	if err != nil {
		// 匹配失败不阻断主流程，仅记录日志
		s.deps.Tracker.Track("kp_match_failed", 0, map[string]interface{}{"error": err.Error()})
		return nil
	}

	type agg struct {
		total int
		wrong int
	}
	m := map[string]*agg{}
	for i, p := range valid {
		if i >= len(batch) {
			break
		}
		name := topMatchName(batch[i])
		if name == "" {
			continue
		}
		a, ok := m[name]
		if !ok {
			a = &agg{}
			m[name] = a
		}
		a.total++
		if p.item.Status == "wrong" || p.item.Status == "half" {
			a.wrong++
		}
	}

	for name, a := range m {
		if a.total == 0 {
			continue
		}
		rate := float64(a.wrong) / float64(a.total)
		kpID := s.findKPID(ctx, db, name, subject)
		row := model.ExamKPResult{
			ExamID:           examID,
			KnowledgePointID: kpID,
			KnowledgeName:    name,
			TotalQuestions:   a.total,
			WrongQuestions:   a.wrong,
			ErrorRate:        rate,
			Level:            MatchLevel(rate),
		}
		if err = db.Create(&row).Error; err != nil {
			return err
		}
	}
	return nil
}

// topMatchName 取匹配结果中相似度最高的知识点名称
func topMatchName(results []ocr.MatchResult) string {
	best := ""
	bestSim := float64(-1)
	for _, r := range results {
		if r.Similarity > bestSim {
			bestSim = r.Similarity
			best = r.Name
		}
	}
	return best
}

// findKPID 按名称在知识点表查找 DB id（找不到返回 0）
func (s *PaperService) findKPID(ctx context.Context, db *gorm.DB, name, subject string) int64 {
	var kp model.KnowledgePoint
	q := db.Where("name = ?", name)
	if subject != "" {
		q = q.Where("subject = ?", subject)
	}
	if err := q.First(&kp).Error; err != nil {
		return 0
	}
	return kp.ID
}

// PaperReport 试卷分析报告聚合
type PaperReport struct {
	Paper      model.Paper         `json:"paper"`
	Exam       model.Exam          `json:"exam"`
	Items      []model.PaperItem   `json:"items"`
	KPResults  []model.ExamKPResult `json:"kp_results"`
}

// GetReport 获取试卷分析报告（校验归属）
func (s *PaperService) GetReport(ctx context.Context, userID, paperID int64) (*PaperReport, error) {
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
		return nil, ErrNotVerified // 越权
	}
	var exam model.Exam
	db.First(&exam, paper.ExamID)
	var items []model.PaperItem
	db.Where("paper_id = ?", paperID).Order("question_num asc").Find(&items)
	var kps []model.ExamKPResult
	db.Where("exam_id = ?", paper.ExamID).Find(&kps)
	return &PaperReport{Paper: paper, Exam: exam, Items: items, KPResults: kps}, nil
}

// ScoreTrend 历次考试得分率趋势（折线图）。可按 student_id / subject / academic_year 过滤。
func (s *PaperService) ScoreTrend(ctx context.Context, userID, studentID int64, subject, academicYear string) ([]model.Exam, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	q := db.Where("user_id = ?", userID)
	if studentID > 0 {
		q = q.Where("student_id = ?", studentID)
	}
	if subject != "" {
		q = q.Where("subject = ?", subject)
	}
	if lo, hi, ok := academicYearRange(academicYear); ok {
		q = q.Where("exam_date >= ? AND exam_date <= ?", lo, hi)
	}
	var exams []model.Exam
	if err = q.Order("exam_date asc").Find(&exams).Error; err != nil {
		return nil, err
	}
	// 体验态：用户无任何模拟考记录时，自动灌入样例分析数据（幂等）
	if len(exams) == 0 {
		if serr := s.seedSampleData(ctx, db, userID); serr == nil {
			var seeded []model.Exam
			if ferr := q.Order("exam_date asc").Find(&seeded).Error; ferr == nil {
				exams = seeded
			}
		}
	}
	return exams, nil
}

// RadarPoint 雷达图一个维度。
type RadarPoint struct {
	Label string  `json:"label"`
	Value float64 `json:"value"`
	Level string  `json:"level,omitempty"` // 仅科目维度返回（urgent/attention/keep）
}

// RadarResponse 能力雷达数据（学生维度或科目维度）。
type RadarResponse struct {
	Scope        string       `json:"scope"` // "student" | "subject"
	StudentID    int64        `json:"student_id"`
	Subject      string       `json:"subject,omitempty"`
	AcademicYear string       `json:"academic_year,omitempty"`
	Points       []RadarPoint `json:"points"`
}

// RadarStudent 学生总能力雷达：该生各科「最新一次考试」的得分率。
// 指定 academic_year 时仅统计该学年内的考试。
func (s *PaperService) RadarStudent(ctx context.Context, userID, studentID int64, academicYear string) (*RadarResponse, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	q := db.Where("user_id = ? AND student_id = ?", userID, studentID)
	if lo, hi, ok := academicYearRange(academicYear); ok {
		q = q.Where("exam_date >= ? AND exam_date <= ?", lo, hi)
	}
	var exams []model.Exam
	if err = q.Order("exam_date asc").Find(&exams).Error; err != nil {
		return nil, err
	}
	// 取每科最新一次考试的得分率（按时间升序遍历，后者覆盖前者）
	latest := map[string]float64{}
	order := []string{}
	for _, e := range exams {
		if _, seen := latest[e.Subject]; !seen {
			order = append(order, e.Subject)
		}
		latest[e.Subject] = e.ScoredRate
	}
	pts := make([]RadarPoint, 0, len(order))
	for _, subj := range order {
		pts = append(pts, RadarPoint{Label: subj, Value: latest[subj]})
	}
	return &RadarResponse{Scope: "student", StudentID: studentID, AcademicYear: academicYear, Points: pts}, nil
}

// RadarSubject 科目能力雷达：该生该科「最新一次考试」的各知识点掌握度。
// 掌握度 = (1 - 错误率) * 100。
func (s *PaperService) RadarSubject(ctx context.Context, userID, studentID int64, subject, academicYear string) (*RadarResponse, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	q := db.Where("user_id = ? AND student_id = ? AND subject = ?", userID, studentID, subject)
	if lo, hi, ok := academicYearRange(academicYear); ok {
		q = q.Where("exam_date >= ? AND exam_date <= ?", lo, hi)
	}
	var exams []model.Exam
	if err = q.Order("exam_date desc").Limit(1).Find(&exams).Error; err != nil {
		return nil, err
	}
	pts := []RadarPoint{}
	if len(exams) > 0 {
		var kps []model.ExamKPResult
		if err = db.Where("exam_id = ?", exams[0].ID).Order("id asc").Find(&kps).Error; err != nil {
			return nil, err
		}
		for _, k := range kps {
			pts = append(pts, RadarPoint{
				Label: k.KnowledgeName,
				Value: round1((1 - k.ErrorRate) * 100),
				Level: k.Level,
			})
		}
	}
	return &RadarResponse{Scope: "subject", StudentID: studentID, Subject: subject, AcademicYear: academicYear, Points: pts}, nil
}

// seedSampleData 为体验账号灌入完整样例：多名学生 + 多个学年 + 多学科，
// 每次考试都包含一份试卷与三档知识点诊断，保证「分析」列表/详情/整体统计共享同一数据源、彼此一致。
// 得分率随学年线性进步（最早学年最低、最新学年最高），知识点错误率随之递减，体现进步曲线。
func (s *PaperService) seedSampleData(ctx context.Context, db *gorm.DB, userID int64) error {
	// 幂等：用户已有任何考试则跳过，避免重复灌入（调用方可能在按学生/学年过滤后结果为空时触发）
	var cnt int64
	db.Model(&model.Exam{}).Where("user_id = ?", userID).Count(&cnt)
	if cnt > 0 {
		return nil
	}

	// 知识点名称（按科目），让样例诊断贴近真实
	kpNames := map[string][]string{
		"语文": {"现代文阅读", "古诗文默写", "作文立意"},
		"数学": {"函数与导数", "解析几何", "概率统计"},
		"英语": {"阅读理解", "完形填空", "书面表达"},
		"物理": {"力学", "电磁学", "热学"},
		"化学": {"有机化学", "电化学", "化学平衡"},
		"生物": {"遗传与进化", "代谢与调节", "稳态与环境"},
		"政治": {"经济生活", "政治生活", "哲学与文化"},
		"历史": {"中国古代史", "中国近现代史", "世界史"},
		"地理": {"自然地理", "人文地理", "区域地理"},
	}

	// 学科样例：r0 = 最早学年(2024-2025)得分率（较低），r2 = 最新学年(2026-2027)得分率（较高）
	type subjDef struct {
		name string
		r0   float64
		r2   float64
	}
	type stuDef struct {
		name  string
		grade string
		exam  string
		subs  []subjDef
	}
	students := []stuDef{
		{"小明", "高三", "新高考", []subjDef{
			{"语文", 74, 84},
			{"数学", 80, 90},
			{"英语", 78, 87},
			{"物理", 76, 86},
			{"化学", 72, 82},
			{"生物", 75, 85},
		}},
		{"小美", "高二", "新高考", []subjDef{
			{"语文", 70, 80},
			{"数学", 68, 80},
			{"英语", 74, 84},
			{"政治", 66, 78},
			{"历史", 72, 82},
			{"地理", 70, 81},
		}},
	}

	// 三个学年（9 月开学制），与小明(高三)/小美(高二)的在校年份吻合
	years := []struct {
		label string
		y     int // 学年起始年份（9 月）
	}{
		{"2024-2025", 2024},
		{"2025-2026", 2025},
		{"2026-2027", 2026},
	}

	for _, st := range students {
		var stu model.Student
		subjNames := make([]string, 0, len(st.subs))
		for _, sd := range st.subs {
			subjNames = append(subjNames, sd.name)
		}
		if err := db.Where("user_id = ? AND name = ?", userID, st.name).FirstOrCreate(&stu, model.Student{
			UserID:   userID,
			Name:     st.name,
			Grade:    st.grade,
			Subjects: model.StringSlice(subjNames),
			ExamType: st.exam,
		}).Error; err != nil {
			return err
		}
		for yi, yr := range years {
			// 该学年两次考试：期中(次年 2 月) + 期末(次年 5 月)，均落在 9 月开学制学年内
			mid := time.Date(yr.y+1, time.February, 15, 0, 0, 0, 0, time.Local)
			final := time.Date(yr.y+1, time.May, 20, 0, 0, 0, 0, time.Local)
			dates := []time.Time{mid, final}
			for ei, d := range dates {
				for _, sd := range st.subs {
					// 学年内线性进步：r0(最早) -> r2(最新)；期末比期中高 3 分
					yearRate := sd.r0 + (sd.r2-sd.r0)*float64(yi)/2.0
					rate := yearRate - float64(1-ei)*3.0
					if rate > 100 {
						rate = 100
					}
					if rate < 0 {
						rate = 0
					}
					exam := model.Exam{
						UserID:     userID,
						StudentID:  stu.ID,
						Name:       fmt.Sprintf("%s·%s%s", st.grade, sd.name, examTag(ei)),
						Subject:    sd.name,
						ExamDate:   d,
						TotalScore: rate / 100 * 150,
						ScoredRate: rate,
					}
					if err := db.Create(&exam).Error; err != nil {
						return err
					}
					paper := model.Paper{UserID: userID, ExamID: exam.ID, Pages: 2, OCRStatus: "completed"}
					pc := d
					paper.OCRCompletedAt = &pc
					if err := db.Create(&paper).Error; err != nil {
						return err
					}
					// 三个知识点：错误率随得分率下降，且有一个相对薄弱点
					baseErr := (100 - rate) / 100
					factors := []float64{1.35, 1.0, 0.65}
					names := kpNames[sd.name]
					for ki, nf := range factors {
						ke := baseErr * nf
						if ke < 0.05 {
							ke = 0.05
						}
						if ke > 0.95 {
							ke = 0.95
						}
						wr := int(ke * 10)
						if err := db.Create(&model.ExamKPResult{
							ExamID:           exam.ID,
							KnowledgePointID: 0,
							KnowledgeName:    names[ki],
							TotalQuestions:   10,
							WrongQuestions:   wr,
							ErrorRate:        ke,
							Level:            kpLevel(ke),
						}).Error; err != nil {
							return err
						}
					}
				}
			}
		}
	}
	s.deps.Tracker.Track("analysis_sample_seed", userID, map[string]interface{}{"students": len(students)})
	return nil
}

// examTag 期中/期末标签。
func examTag(ei int) string {
	if ei == 0 {
		return "期中"
	}
	return "期末"
}

// kpLevel 根据错误率给出三档诊断
func kpLevel(er float64) string {
	switch {
	case er >= 0.5:
		return "urgent"
	case er >= 0.2:
		return "attention"
	default:
		return "keep"
	}
}

// KnowledgeTrend 单知识点历次错误率趋势
func (s *PaperService) KnowledgeTrend(ctx context.Context, userID, kpID int64) ([]model.ExamKPResult, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var results []model.ExamKPResult
	err = db.Where("knowledge_point_id = ?", kpID).
		Joins("JOIN exams ON exams.id = exam_kp_results.exam_id").
		Where("exams.user_id = ?", userID).
		Order("exams.exam_date asc").
		Find(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}

// TierDistribution 最新一次考试的三档分布
func (s *PaperService) TierDistribution(ctx context.Context, userID, examID int64) (map[string]int, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	if examID == 0 {
		// 取该用户最新考试
		var exam model.Exam
		if err = db.Where("user_id = ?", userID).Order("exam_date desc").First(&exam).Error; err != nil {
			if err == gorm.ErrRecordNotFound {
				return map[string]int{"urgent": 0, "attention": 0, "keep": 0}, nil
			}
			return nil, err
		}
		examID = exam.ID
	}
	var results []model.ExamKPResult
	if err = db.Where("exam_id = ?", examID).Find(&results).Error; err != nil {
		return nil, err
	}
	dist := map[string]int{"urgent": 0, "attention": 0, "keep": 0}
	for _, r := range results {
		dist[r.Level]++
	}
	return dist, nil
}

// Share 分享分析报告到外部渠道，成功后赠送 1 次奖励分析次数
func (s *PaperService) Share(ctx context.Context, userID, paperID int64, channel string) error {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return err
	}
	var paper model.Paper
	if err = db.First(&paper, paperID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return ErrNotFound
		}
		return err
	}
	if paper.UserID != userID {
		return ErrNotVerified
	}
	rec := model.ShareRecord{UserID: userID, ReportID: paperID, ReportType: "paper", Channel: channel}
	if err = db.Create(&rec).Error; err != nil {
		return err
	}
	// 分享获取奖励次数（+1，单次分享封顶，避免刷）
	if err = s.deps.AddBonusQuota(ctx, userID, 1); err != nil {
		return err
	}
	s.deps.Tracker.Track("paper_share", userID, map[string]interface{}{"paper_id": paperID, "channel": channel})
	s.deps.Tracker.Track("invite_used", userID, map[string]interface{}{"source": "share_bonus"})
	return nil
}

// GetQuota 返回用户当月剩余分析次数
func (s *PaperService) GetQuota(ctx context.Context, userID int64) (freeRemain, bonusRemain int, err error) {
	return s.deps.RemainingQuota(ctx, userID)
}

// AnalysisSummary 过往分析的简要聚合（用于「分析」列表）。
type AnalysisSummary struct {
	PaperID   int64   `json:"paper_id"`
	ExamName  string  `json:"exam_name"`
	Subject   string  `json:"subject"`
	ScoreRate float64 `json:"score_rate"`
	ExamDate  string  `json:"exam_date"`
	CreatedAt string  `json:"created_at"`
	Urgent    int     `json:"urgent"`
	Attention int     `json:"attention"`
	Keep      int     `json:"keep"`
	HasReport bool    `json:"has_report"`
}

// ListMyAnalyses 我的过往分析列表（按时间倒序）。无数据时幂等预置样例。
func (s *PaperService) ListMyAnalyses(ctx context.Context, userID int64) ([]AnalysisSummary, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var papers []model.Paper
	if err = db.Where("user_id = ?", userID).Order("created_at desc").Find(&papers).Error; err != nil {
		return nil, err
	}
	if len(papers) == 0 {
		if serr := s.seedSampleData(ctx, db, userID); serr == nil {
			db.Where("user_id = ?", userID).Order("created_at desc").Find(&papers)
		}
	}
	out := make([]AnalysisSummary, 0, len(papers))
	for _, p := range papers {
		var exam model.Exam
		db.First(&exam, p.ExamID)
		var kps []model.ExamKPResult
		db.Where("exam_id = ?", p.ExamID).Find(&kps)
		tier := map[string]int{"urgent": 0, "attention": 0, "keep": 0}
		for _, r := range kps {
			tier[r.Level]++
		}
		out = append(out, AnalysisSummary{
			PaperID:   p.ID,
			ExamName:  exam.Name,
			Subject:   exam.Subject,
			ScoreRate: exam.ScoredRate,
			ExamDate:  formatDateOnly(exam.ExamDate),
			CreatedAt: formatDateTime(&p.CreatedAt),
			Urgent:    tier["urgent"],
			Attention: tier["attention"],
			Keep:      tier["keep"],
			HasReport: len(kps) > 0,
		})
	}
	return out, nil
}

// AnalysisOverview 「分析」页顶部整体统计。
type AnalysisOverview struct {
	TotalAnalyses int64            `json:"total_analyses"`
	AvgScoreRate  float64          `json:"avg_score_rate"`
	LatestExam    *ExamBrief       `json:"latest_exam"`
	FirstRate     float64          `json:"first_rate"`
	Progress      float64          `json:"progress"` // 较首次提升的百分点
	Tier          map[string]int   `json:"tier"`
	TotalKP       int64            `json:"total_kp"`
}

// ExamBrief 考试简要信息。
type ExamBrief struct {
	Name      string  `json:"name"`
	ScoreRate float64 `json:"score_rate"`
	ExamDate  string  `json:"exam_date"`
	Subject   string  `json:"subject"`
}

// GetOverview 整体分析统计。无数据时幂等预置样例。
func (s *PaperService) GetOverview(ctx context.Context, userID int64) (*AnalysisOverview, error) {
	db, err := s.deps.ctxDB(ctx)
	if err != nil {
		return nil, err
	}
	var exams []model.Exam
	if err = db.Where("user_id = ?", userID).Order("exam_date asc").Find(&exams).Error; err != nil {
		return nil, err
	}
	if len(exams) == 0 {
		// 统一预置样例数据，让整体分析呈现完整进步曲线
		if serr := s.seedSampleData(ctx, db, userID); serr == nil {
			db.Where("user_id = ?", userID).Order("exam_date asc").Find(&exams)
		}
	}
	ov := &AnalysisOverview{Tier: map[string]int{"urgent": 0, "attention": 0, "keep": 0}}
	ov.TotalAnalyses = int64(len(exams))
	if len(exams) > 0 {
		var sum float64
		for _, e := range exams {
			sum += e.ScoredRate
		}
		ov.AvgScoreRate = round1(sum / float64(len(exams)))
		first := exams[0]
		last := exams[len(exams)-1]
		ov.FirstRate = first.ScoredRate
		ov.Progress = round1(last.ScoredRate - first.ScoredRate)
		ov.LatestExam = &ExamBrief{
			Name:      last.Name,
			ScoreRate: last.ScoredRate,
			ExamDate:  formatDateOnly(last.ExamDate),
			Subject:   last.Subject,
		}
	}
	// 三档汇总（跨所有考试的 kp 结果）
	var kps []model.ExamKPResult
	db.Table("exam_kp_results").
		Joins("JOIN exams ON exams.id = exam_kp_results.exam_id").
		Where("exams.user_id = ?", userID).
		Find(&kps)
	for _, r := range kps {
		ov.Tier[r.Level]++
	}
	ov.TotalKP = int64(len(kps))
	return ov, nil
}

// 注：样例数据已由 seedSampleData 统一预置（每次考试均含试卷与三档知识点诊断）。

// round1 保留 1 位小数。
func round1(v float64) float64 {
	return float64(int(v*10+0.5)) / 10
}

// formatDateOnly 仅日期 YYYY-MM-DD。
func formatDateOnly(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.Format("2006-01-02")
}

// formatDateTime 日期时间（前端可直接显示）。
func formatDateTime(t *time.Time) string {
	if t == nil || t.IsZero() {
		return ""
	}
	return t.Format("2006-01-02 15:04")
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func orDefault(v, def string) string {
	if v == "" {
		return def
	}
	return v
}
