package middleware

import (
	"context"
	"time"

	"github.com/gofiber/fiber/v2"
)

// TimeoutMiddleware sets a deadline on the request context equal to timeout.
// All downstream handlers receive this context via c.UserContext(), so
// context-aware operations (database queries, HTTP calls) are automatically
// cancelled when the deadline is exceeded.
//
// Note: this relies on handlers honouring context cancellation. Handlers that
// block without checking ctx.Done() will not be forcibly interrupted, but
// every DB call through pgx already does this correctly.
func TimeoutMiddleware(timeout time.Duration) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(c.Context(), timeout)
		defer cancel()
		c.SetUserContext(ctx)
		return c.Next()
	}
}
