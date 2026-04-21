package handlers

import (
	"context"

	"github.com/momarinho/rep_engine/internal/db"

	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
)

func Register(c *fiber.Ctx) error {
	type Input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	var input Input
	if err := c.BodyParser(&input); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request"})
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to hash password"})
	}

	// Insert user
	_, err = db.Pool.Exec(context.Background(),
		"INSERT INTO users (email, password_hash) VALUES ($1, $2)",
		input.Email, string(hash),
	)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "email already exists"})
	}

	return c.JSON(fiber.Map{"message": "user created"})
}

func Login(c *fiber.Ctx) error {
	// ... verify credentials and generate JWT (coming next)
	return c.JSON(fiber.Map{"message": "login endpoint"})
}

func Logout(c *fiber.Ctx) error {
	// ... clear cookie (coming next)
	return c.JSON(fiber.Map{"message": "logout endpoint"})
}
