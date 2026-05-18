package authn

import (
	"os"
	"strings"
)

const (
	defaultJWTIssuer   = "repengine"
	defaultJWTAudience = "repengine"
)

func JWTSecret() string {
	return strings.TrimSpace(os.Getenv("JWT_SECRET"))
}

func JWTIssuer() string {
	value := strings.TrimSpace(os.Getenv("JWT_ISSUER"))
	if value == "" {
		return defaultJWTIssuer
	}
	return value
}

func JWTAudience() string {
	value := strings.TrimSpace(os.Getenv("JWT_AUDIENCE"))
	if value == "" {
		return defaultJWTAudience
	}
	return value
}

func CookieSecure() bool {
	switch strings.ToLower(strings.TrimSpace(os.Getenv("APP_ENV"))) {
	case "production", "staging":
		return true
	default:
		return false
	}
}

func NormalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}
