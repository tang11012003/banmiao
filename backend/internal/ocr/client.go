package ocr

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"strings"
	"time"
)

// Question 单道题的 OCR 识别结果
type Question struct {
	QuestionNum int     `json:"question_num"`
	Text        string  `json:"text"`
	Status      string  `json:"status"` // correct, wrong, half, unanswered
	MaxScore    float64 `json:"max_score"`
	ActualScore float64 `json:"actual_score"`
	Confidence  float64 `json:"confidence"`
}

// AnalyzeResult OCR 分析总结果
type AnalyzeResult struct {
	Success         bool      `json:"success"`
	TotalQuestions  int       `json:"total_questions"`
	CorrectCount    int       `json:"correct_count"`
	WrongCount      int       `json:"wrong_count"`
	HalfCount       int       `json:"half_count"`
	UnansweredCount int       `json:"unanswered_count"`
	ScoreRate       float64   `json:"score_rate"`
	Questions       []Question `json:"questions"`
	Message         string    `json:"message"`
}

// MatchResult 单个知识点匹配结果
type MatchResult struct {
	KnowledgePointID int     `json:"knowledge_point_id"`
	Name             string  `json:"name"`
	Similarity       float64 `json:"similarity"`
	Matched          bool    `json:"matched"`
}

// MatchResponse 知识点匹配响应
type MatchResponse struct {
	Success bool          `json:"success"`
	Results []MatchResult `json:"results"`
	Message string        `json:"message"`
}

// Client OCR 服务客户端，所有调用都带超时与错误兜底
type Client struct {
	baseURL string
	http    *http.Client
}

// NewClient 创建 OCR 客户端，baseURL 形如 http://localhost:8000
func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		http:    &http.Client{Timeout: 30 * time.Second},
	}
}

// Analyze 调用 POST /api/ocr/analyze 进行试卷对错识别。
// 调用失败（网络错误 / 超时 / 非 2xx / success=false）统一返回 error，由上层兜底。
func (c *Client) Analyze(ctx context.Context, file multipart.File, filename string) (*AnalyzeResult, error) {
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	// 按文件名扩展名设置正确的 Content-Type，否则默认 application/octet-stream
	// 会被 OCR 服务的文件类型白名单拦截（返回 400）。
	h := make(textproto.MIMEHeader)
	h.Set("Content-Disposition", fmt.Sprintf(`form-data; name="file"; filename="%s"`, filename))
	h.Set("Content-Type", contentTypeFromName(filename))
	part, err := writer.CreatePart(h)
	if err != nil {
		return nil, fmt.Errorf("构造上传表单失败: %w", err)
	}
	if _, err = io.Copy(part, file); err != nil {
		return nil, fmt.Errorf("读取试卷文件失败: %w", err)
	}
	if err = writer.Close(); err != nil {
		return nil, fmt.Errorf("关闭上传表单失败: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/ocr/analyze", body)
	if err != nil {
		return nil, fmt.Errorf("构造 OCR 请求失败: %w", err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("OCR 服务调用失败(可能未启动): %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取 OCR 响应失败: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("OCR 服务返回非 200 状态: %d, body=%s", resp.StatusCode, string(data))
	}

	var result AnalyzeResult
	if err = json.Unmarshal(data, &result); err != nil {
		return nil, fmt.Errorf("解析 OCR 响应失败: %w", err)
	}
	if !result.Success {
		return nil, fmt.Errorf("OCR 识别失败: %s", result.Message)
	}
	return &result, nil
}

// Match 调用 POST /api/knowledge/match 匹配单个错题的知识点
func (c *Client) Match(ctx context.Context, questionText, subject string, topK int, threshold float64) ([]MatchResult, error) {
	payload := map[string]interface{}{
		"question_text": questionText,
		"subject":       subject,
		"top_k":         topK,
		"threshold":     threshold,
	}
	return c.doMatch(ctx, c.baseURL+"/api/knowledge/match", payload)
}

// BatchMatch 调用 POST /api/knowledge/batch-match 批量匹配
func (c *Client) BatchMatch(ctx context.Context, texts []string, subject string, topK int, threshold float64) ([][]MatchResult, error) {
	questions := make([]map[string]string, 0, len(texts))
	for _, t := range texts {
		questions = append(questions, map[string]string{"text": t})
	}
	payload := map[string]interface{}{
		"questions": questions,
		"subject":   subject,
		"top_k":     topK,
		"threshold": threshold,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("构造批量匹配请求失败: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/knowledge/batch-match", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("构造批量匹配请求失败: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("OCR 知识匹配服务调用失败(可能未启动): %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取知识匹配响应失败: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("知识匹配服务返回非 200 状态: %d, body=%s", resp.StatusCode, string(data))
	}

	// 复用 MatchResponse 的结构（results 为二维数组）——单独解析
	var batch struct {
		Success bool            `json:"success"`
		Results [][]MatchResult `json:"results"`
		Message string          `json:"message"`
	}
	if err = json.Unmarshal(data, &batch); err != nil {
		return nil, fmt.Errorf("解析批量匹配响应失败: %w", err)
	}
	if !batch.Success {
		return nil, fmt.Errorf("知识点批量匹配失败: %s", batch.Message)
	}
	return batch.Results, nil
}

// doMatch 内部方法，处理单题匹配
func (c *Client) doMatch(ctx context.Context, url string, payload map[string]interface{}) ([]MatchResult, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("构造匹配请求失败: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("构造匹配请求失败: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("OCR 知识匹配服务调用失败(可能未启动): %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取知识匹配响应失败: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("知识匹配服务返回非 200 状态: %d, body=%s", resp.StatusCode, string(data))
	}

	var m MatchResponse
	if err = json.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("解析匹配响应失败: %w", err)
	}
	if !m.Success {
		return nil, fmt.Errorf("知识点匹配失败: %s", m.Message)
	}
	return m.Results, nil
}

// contentTypeFromName 根据文件名扩展名推断 MIME 类型（默认 image/png）
func contentTypeFromName(filename string) string {
	lower := strings.ToLower(filename)
	switch {
	case strings.HasSuffix(lower, ".jpg"), strings.HasSuffix(lower, ".jpeg"):
		return "image/jpeg"
	case strings.HasSuffix(lower, ".png"):
		return "image/png"
	default:
		return "image/png"
	}
}
