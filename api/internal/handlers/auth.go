package handlers

import (
	"errors"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/momarinho/rep_engine/internal/authn"
	"github.com/momarinho/rep_engine/internal/db"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	"golang.org/x/crypto/bcrypt"
)

func Register(c *fiber.Ctx) error {
	type Input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	var input Input
	if err := c.BodyParser(&input); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}
	if err := authn.ValidateRegistrationInput(input.Email, input.Password); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	normalizedEmail := authn.NormalizeEmail(input.Email)

	var exists bool
	if err := db.Pool.QueryRow(c.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(email) = $1)`,
		normalizedEmail,
	).Scan(&exists); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}
	if exists {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("email already exists"))
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	_, err = db.Pool.Exec(c.Context(),
		"INSERT INTO users (email, password_hash) VALUES ($1, $2)",
		normalizedEmail, string(hash),
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return apperrors.WriteAppError(c, apperrors.ErrBadRequest("email already exists"))
		}
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	return c.JSON(fiber.Map{"message": "user created"})
}

func Login(c *fiber.Ctx) error {
	type Input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	var input Input
	if err := c.BodyParser(&input); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}
	if err := authn.ValidateLoginInput(input.Email, input.Password); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	var id int
	var passwordHash string
	var tokenVersion int
	err := db.Pool.QueryRow(c.Context(),
		"SELECT id, password_hash, token_version FROM users WHERE LOWER(email) = $1",
		authn.NormalizeEmail(input.Email),
	).Scan(&id, &passwordHash, &tokenVersion)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash),
		[]byte(input.Password),
	); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	tokenString, err := authn.SignToken(id, tokenVersion, time.Now().UTC())
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	c.Cookie(&fiber.Cookie{
		Name:     "token",
		Value:    tokenString,
		Path:     "/",
		HTTPOnly: true,
		Secure:   authn.CookieSecure(),
		SameSite: "Lax",
		MaxAge:   86400,
	})

	return c.JSON(fiber.Map{"message": "logged in", "user_id": id, "token": tokenString})
}

func Logout(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(int)
	if !ok || userID <= 0 {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	if _, err := db.Pool.Exec(c.Context(),
		`UPDATE users SET token_version = token_version + 1 WHERE id = $1`,
		userID,
	); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	c.Cookie(&fiber.Cookie{
		Name:     "token",
		Value:    "",
		Path:     "/",
		HTTPOnly: true,
		Secure:   authn.CookieSecure(),
		SameSite: "Lax",
		MaxAge:   -1,
	})
	return c.JSON(fiber.Map{"message": "logged out"})
}
