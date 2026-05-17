package logger

import (
	"log/slog"
	"os"
	"strings"
)

// Init returns a JSON logger at INFO level.  It exists for backwards
// compatibility; prefer New when a log level is known at startup.
func Init() *slog.Logger {
	return New("info")
}

// New returns a JSON logger writing to stdout at the requested level.
// Recognised level strings (case-insensitive): "debug", "info", "warn" /
// "warning", "error".  Any other value defaults to INFO.
func New(level string) *slog.Logger {
	var l slog.Level
	switch strings.ToLower(level) {
	case "debug":
		l = slog.LevelDebug
	case "warn", "warning":
		l = slog.LevelWarn
	case "error":
		l = slog.LevelError
	default:
		l = slog.LevelInfo
	}
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: l})
	return slog.New(handler)
}
