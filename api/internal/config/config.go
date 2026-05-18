package config

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds all application configuration loaded from environment variables.
type Config struct {
	DatabaseURL string
	JWTSecret   string
	Port        string // default "8080"
	AppEnv      string // default "development"
	LogLevel    string // default "info"
	CORSOrigins string // default development localhost origins
	Version     string // injected at build time via ldflags
	BuildTime   string // injected at build time via ldflags
}

// Load reads environment variables (optionally from a .env file) and returns a
// populated Config.  version and buildTime are passed in from the main package
// where they are set via -ldflags.
func Load(version, buildTime string) (*Config, error) {
	if err := godotenv.Load(); err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, fmt.Errorf("config: load .env file: %w", err)
	}

	// Collect all missing required variables before returning so the caller
	// sees every problem at once rather than one at a time.
	var missing []string

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		missing = append(missing, "DATABASE_URL")
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		missing = append(missing, "JWT_SECRET")
	}

	if len(missing) > 0 {
		return nil, fmt.Errorf(
			"config: missing required environment variables: %s",
			strings.Join(missing, ", "),
		)
	}

	// Optional variables with defaults.
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	appEnv := os.Getenv("APP_ENV")
	if appEnv == "" {
		appEnv = "development"
	}

	logLevel := os.Getenv("LOG_LEVEL")
	if logLevel == "" {
		logLevel = "info"
	}

	corsOrigins := os.Getenv("CORS_ORIGINS")
	if corsOrigins == "" {
		corsOrigins = "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173"
	}

	return &Config{
		DatabaseURL: databaseURL,
		JWTSecret:   jwtSecret,
		Port:        port,
		AppEnv:      appEnv,
		LogLevel:    logLevel,
		CORSOrigins: corsOrigins,
		Version:     version,
		BuildTime:   buildTime,
	}, nil
}
