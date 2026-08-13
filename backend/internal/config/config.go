package config

import (
	"os"
	"strconv"
	"time"
)

// Config 应用配置
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	Neo4j    Neo4jConfig
	JWT      JWTConfig
	OCR      OCRConfig
	App      AppConfig
}

// AppConfig 业务配置
type AppConfig struct {
	GaokaoDate string `json:"gaokao_date"` // 高考日期，格式 2006-01-02，用于倒计时
}

// ServerConfig 服务器配置
type ServerConfig struct {
	Port         int           `json:"port"`
	ReadTimeout  time.Duration `json:"read_timeout"`
	WriteTimeout time.Duration `json:"write_timeout"`
	Mode         string        `json:"mode"` // debug, release, test
}

// DatabaseConfig 数据库配置
type DatabaseConfig struct {
	Host     string `json:"host"`
	Port     int    `json:"port"`
	User     string `json:"user"`
	Password string `json:"password"`
	DBName   string `json:"db_name"`
	SSLMode  string `json:"ssl_mode"`
}

// RedisConfig Redis 配置
type RedisConfig struct {
	Addr     string `json:"addr"`
	Password string `json:"password"`
	DB       int    `json:"db"`
}

// Neo4jConfig Neo4j 配置
type Neo4jConfig struct {
	URI      string `json:"uri"`
	Username string `json:"username"`
	Password string `json:"password"`
}

// JWTConfig JWT 配置
type JWTConfig struct {
	Secret     string        `json:"secret"`
	Expiration time.Duration `json:"expiration"`
}

// OCRConfig OCR 服务配置
type OCRConfig struct {
	BaseURL string `json:"base_url"`
}

// Load 加载配置
func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port:         getEnvInt("SERVER_PORT", 8080),
			ReadTimeout:  10 * time.Second,
			WriteTimeout: 10 * time.Second,
			Mode:         getEnv("GIN_MODE", "debug"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnvInt("DB_PORT", 5432),
			User:     getEnv("DB_USER", "peidu"),
			Password: getEnv("DB_PASSWORD", ""),
			DBName:   getEnv("DB_NAME", "peidu_community"),
			SSLMode:  getEnv("DB_SSL_MODE", "disable"),
		},
		Redis: RedisConfig{
			Addr:     getEnv("REDIS_ADDR", "localhost:6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvInt("REDIS_DB", 0),
		},
		Neo4j: Neo4jConfig{
			URI:      getEnv("NEO4J_URI", "bolt://localhost:7687"),
			Username: getEnv("NEO4J_USERNAME", "neo4j"),
			Password: getEnv("NEO4J_PASSWORD", ""),
		},
		JWT: JWTConfig{
			Secret:     getEnv("JWT_SECRET", "change-me-in-production"),
			Expiration: 24 * time.Hour,
		},
		OCR: OCRConfig{
			BaseURL: getEnv("OCR_SERVICE_URL", "http://localhost:8000"),
		},
		App: AppConfig{
			GaokaoDate: getEnv("GAOKAO_DATE", "2027-06-07"),
		},
	}
}

// DSN 返回 PostgreSQL 连接字符串
func (d *DatabaseConfig) DSN() string {
	return "host=" + d.Host +
		" port=" + strconv.Itoa(d.Port) +
		" user=" + d.User +
		" password=" + d.Password +
		" dbname=" + d.DBName +
		" sslmode=" + d.SSLMode
}

func getEnv(key, defaultValue string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return defaultValue
}
