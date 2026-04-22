package middleware

import (
	"log/slog"
	"time"

	"github.com/gofiber/fiber/v2"
)

func Logging(logger *slog.Logger) fiber.Handler {
	return func(c *fiber.Ctx) error {
		requestID := c.Locals("request_id").(string)
		start := time.Now()

		err := c.Next()

		duration := time.Since(start)
		logger.Info("request completed",
			"request_id", requestID,
			"method", c.Method(),
			"path", c.Path(),
			"status_code", c.Response().StatusCode(),
			"duration_ms", duration.Milliseconds(),
			"level", "info",
		)
		return err
	}
}
