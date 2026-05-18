package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/momarinho/rep_engine/internal/authn"
	"github.com/momarinho/rep_engine/internal/db"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

func RequireAuth(c *fiber.Ctx) error {
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

	claims, err := authn.ParseToken(tokenString)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	var tokenVersion int
	err = db.Pool.QueryRow(c.Context(),
		`SELECT token_version FROM users WHERE id = $1`,
		claims.UserID,
	).Scan(&tokenVersion)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}
	if tokenVersion != claims.TokenVersion {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	c.Locals("user_id", claims.UserID)
	c.Locals("token_version", claims.TokenVersion)
	return c.Next()
}
