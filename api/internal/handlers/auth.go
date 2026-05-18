package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/momarinho/rep_engine/internal/authn"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

func (a *App) Register(c *fiber.Ctx) error {
	type input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	var req input
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}

	out, err := a.auth.Register(c.UserContext(), authn.RegisterInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(fiber.Map{
		"message": "user created",
		"user_id": out.UserID,
	})
}

func (a *App) Login(c *fiber.Ctx) error {
	type input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	var req input
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}

	out, err := a.auth.Login(c.UserContext(), authn.LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	c.Cookie(&fiber.Cookie{
		Name:     "token",
		Value:    out.Token,
		Path:     "/",
		HTTPOnly: true,
		Secure:   authn.CookieSecure(),
		SameSite: "Lax",
		MaxAge:   86400,
	})

	return c.JSON(fiber.Map{
		"message": "logged in",
		"user_id": out.UserID,
		"token":   out.Token,
	})
}

func (a *App) Logout(c *fiber.Ctx) error {
	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID, ok := c.Locals("user_id").(int)
	if !ok || userID <= 0 {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	if err := a.auth.Logout(c.UserContext(), userID); err != nil {
		return apperrors.WriteAppError(c, err)
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
