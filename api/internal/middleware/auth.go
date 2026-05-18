package middleware

import (
	"context"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/momarinho/rep_engine/internal/authn"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

type tokenAuthenticator interface {
	AuthenticateToken(ctx context.Context, tokenString string) (*authn.Claims, error)
}

func RequireAuth(authService tokenAuthenticator) fiber.Handler {
	return func(c *fiber.Ctx) error {
		if authService == nil {
			return apperrors.WriteAppError(c, apperrors.ErrInternal())
		}

		tokenString := ""

		// try auth Bearer <token>
		authHeader := strings.TrimSpace(c.Get("Authorization"))
		if len(authHeader) > 7 && strings.EqualFold(authHeader[:7], "Bearer ") {
			tokenString = strings.TrimSpace(authHeader[7:])
		}

		// fallback
		if tokenString == "" {
			tokenString = strings.TrimSpace(c.Cookies("token"))
		}

		if tokenString == "" {
			return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
		}

		claims, err := authService.AuthenticateToken(c.UserContext(), tokenString)
		if err != nil {
			return apperrors.WriteAppError(c, err)
		}

		c.Locals("user_id", claims.UserID)
		c.Locals("token_version", claims.TokenVersion)
		return c.Next()
	}
}
