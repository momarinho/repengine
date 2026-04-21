package handlers

import (
	"context"
	"os"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/momarinho/rep_engine/internal/db"
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
	type Input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	var input Input
	if err := c.BodyParser(&input); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request"})
	}

	// Find user
	var id int
	var passwordHash string
	err := db.Pool.QueryRow(context.Background(),
		"SELECT id, password_hash FROM users WHERE email = $1", input.Email,
	).Scan(&id, &passwordHash)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "invalid credentials"})
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash),
		[]byte(input.Password),
	); err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "invalid credentials"})
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": id,
		"exp":     time.Now().Add(24 * time.Hour).Unix(),
	})

	tokenString, err := token.SignedString([]byte(os.Getenv("JWT_SECRET")))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to generate token"})
	}

	c.Cookie(&fiber.Cookie{
		Name:     "token",
		Value:    tokenString,
		HTTPOnly: true,
		Secure:   false, // true in prod with HTTPS
		SameSite: "Lax",
		MaxAge:   86400,
	})

	return c.JSON(fiber.Map{"message": "logged in", "user_id": id})
}

func Logout(c *fiber.Ctx) error {
	c.Cookie(&fiber.Cookie{
		Name:     "token",
		Value:    "",
		HTTPOnly: true,
		Secure:   false,
		SameSite: "Lax",
		MaxAge:   -1, // expires immediately
	})
	return c.JSON(fiber.Map{"message": "logged out"})
}
