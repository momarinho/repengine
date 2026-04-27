package middleware

import (
	"os"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
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

	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, apperrors.ErrUnauthorized()
		}
		return []byte(os.Getenv("JWT_SECRET")), nil
	})
	if err != nil || !token.Valid {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	userIDValue, ok := claims["user_id"].(float64)
	if !ok {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	c.Locals("user_id", int(userIDValue))
	return c.Next()
}
