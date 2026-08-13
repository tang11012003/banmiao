package service

import "errors"

// ErrDBUnavailable 数据库未连接时返回，handler 会映射为 503
var ErrDBUnavailable = errors.New("数据库不可用")

// ErrQuotaExhausted 当月分析次数已用尽
var ErrQuotaExhausted = errors.New("分析次数已用尽，分享可获取更多次数")

// ErrNotVerified 用户未完成家长认证
var ErrNotVerified = errors.New("用户未完成家长认证")

// ErrNotFound 资源不存在
var ErrNotFound = errors.New("资源不存在")
