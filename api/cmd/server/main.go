package main

import (
	"context"
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/momarinho/rep_engine/internal/db"
	"github.com/momarinho/rep_engine/internal/handlers"
)

func main() {
	if err := db.Connect(); err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}
	defer db.Close()

	if err := db.RunMigrations(context.Background()); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	app := fiber.New()

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	auth := app.Group("/auth")
	auth.Post("/register", handlers.Register)
	auth.Post("/login", handlers.Login)
	auth.Post("/logout", handlers.Logout)

	app.Listen(":8080")
}
