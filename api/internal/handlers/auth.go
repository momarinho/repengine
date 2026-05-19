package handlers

import (
	"os"

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

func (a *App) GetAccount(c *fiber.Ctx) error {
	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID, ok := c.Locals("user_id").(int)
	if !ok || userID <= 0 {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	account, err := a.auth.GetAccount(c.UserContext(), userID)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(account)
}

func (a *App) UpdateAccount(c *fiber.Ctx) error {
	type input struct {
		Email           string `json:"email"`
		CurrentPassword string `json:"current_password"`
		NewPassword     string `json:"new_password"`
	}

	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID, ok := c.Locals("user_id").(int)
	if !ok || userID <= 0 {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	var req input
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}

	out, err := a.auth.UpdateAccount(c.UserContext(), authn.UpdateAccountInput{
		UserID:          userID,
		Email:           req.Email,
		CurrentPassword: req.CurrentPassword,
		NewPassword:     req.NewPassword,
	})
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	clearTokenCookie(c)
	return c.JSON(out)
}

func (a *App) DeleteAccount(c *fiber.Ctx) error {
	type input struct {
		CurrentPassword string `json:"current_password"`
	}

	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID, ok := c.Locals("user_id").(int)
	if !ok || userID <= 0 {
		return apperrors.WriteAppError(c, apperrors.ErrUnauthorized())
	}

	var req input
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}

	if err := a.auth.DeleteAccount(c.UserContext(), authn.DeleteAccountInput{
		UserID:          userID,
		CurrentPassword: req.CurrentPassword,
	}); err != nil {
		return apperrors.WriteAppError(c, err)
	}

	clearTokenCookie(c)
	return c.JSON(fiber.Map{"message": "account deleted"})
}

func (a *App) RequestPasswordReset(c *fiber.Ctx) error {
	type input struct {
		Email string `json:"email"`
	}

	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	var req input
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}

	out, err := a.auth.RequestPasswordReset(c.UserContext(), authn.RequestPasswordResetInput{
		Email: req.Email,
	})
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	payload := fiber.Map{
		"message": "If the account exists, a password reset link has been created.",
	}
	if out.ResetToken != "" && os.Getenv("APP_ENV") != "production" {
		payload["reset_token"] = out.ResetToken
	}

	return c.JSON(payload)
}

func (a *App) ResetPassword(c *fiber.Ctx) error {
	type input struct {
		Token       string `json:"token"`
		NewPassword string `json:"new_password"`
	}

	if a.auth == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	var req input
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request"))
	}

	if err := a.auth.ResetPassword(c.UserContext(), authn.ResetPasswordInput{
		Token:       req.Token,
		NewPassword: req.NewPassword,
	}); err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(fiber.Map{"message": "password reset"})
}

func clearTokenCookie(c *fiber.Ctx) {
	c.Cookie(&fiber.Cookie{
		Name:     "token",
		Value:    "",
		Path:     "/",
		HTTPOnly: true,
		Secure:   authn.CookieSecure(),
		SameSite: "Lax",
		MaxAge:   -1,
	})
}
