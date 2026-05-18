package middleware

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/joho/godotenv"
	"github.com/momarinho/rep_engine/internal/authn"
	"github.com/momarinho/rep_engine/internal/db"
	"github.com/momarinho/rep_engine/internal/handlers"
	"golang.org/x/crypto/bcrypt"
)

func setupAuthIntegrationDB(t *testing.T) {
	t.Helper()

	oldPool := db.Pool

	if os.Getenv("DATABASE_URL") == "" {
		_ = godotenv.Load("../../.env")
	}
	if os.Getenv("DATABASE_URL") == "" {
		t.Skip("skipping integration test: DATABASE_URL is not set")
	}

	if err := db.Connect(); err != nil {
		t.Skipf("skipping integration test: database unavailable: %v", err)
	}

	if err := db.RunMigrations(context.Background()); err != nil {
		t.Fatalf("RunMigrations failed: %v", err)
	}

	t.Cleanup(func() {
		db.Close()
		db.Pool = oldPool
	})
}

func createAuthIntegrationUser(t *testing.T, email, password string) (int, int) {
	t.Helper()

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("GenerateFromPassword failed: %v", err)
	}

	var userID int
	var tokenVersion int
	err = db.Pool.QueryRow(context.Background(), `
		INSERT INTO users (email, password_hash)
		VALUES ($1, $2)
		RETURNING id, token_version
	`, email, string(hash)).Scan(&userID, &tokenVersion)
	if err != nil {
		t.Fatalf("failed to create test user: %v", err)
	}

	t.Cleanup(func() {
		_, _ = db.Pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
	})

	return userID, tokenVersion
}

func TestLogoutInvalidatesBearerToken(t *testing.T) {
	t.Setenv("JWT_SECRET", "integration-secret-value")
	t.Setenv("JWT_ISSUER", "repengine-api")
	t.Setenv("JWT_AUDIENCE", "repengine-web")
	t.Setenv("APP_ENV", "development")

	setupAuthIntegrationDB(t)

	email := fmt.Sprintf("logout-%d@example.com", time.Now().UnixNano())
	userID, tokenVersion := createAuthIntegrationUser(t, email, "password123")

	token, err := authn.SignToken(userID, tokenVersion, time.Now().UTC())
	if err != nil {
		t.Fatalf("SignToken returned error: %v", err)
	}

	app := fiber.New()
	app.Post("/auth/logout", RequireAuth, handlers.Logout)
	app.Get("/protected", RequireAuth, func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"ok": true})
	})

	protectedBefore := httptest.NewRequest("GET", "/protected", nil)
	protectedBefore.Header.Set("Authorization", "Bearer "+token)

	protectedBeforeResp, err := app.Test(protectedBefore)
	if err != nil {
		t.Fatalf("protected request before logout failed: %v", err)
	}
	if protectedBeforeResp.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 before logout, got %d", protectedBeforeResp.StatusCode)
	}

	logoutReq := httptest.NewRequest("POST", "/auth/logout", nil)
	logoutReq.Header.Set("Authorization", "Bearer "+token)

	logoutResp, err := app.Test(logoutReq)
	if err != nil {
		t.Fatalf("logout request failed: %v", err)
	}
	if logoutResp.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 on logout, got %d", logoutResp.StatusCode)
	}

	protectedAfter := httptest.NewRequest("GET", "/protected", nil)
	protectedAfter.Header.Set("Authorization", "Bearer "+token)

	protectedAfterResp, err := app.Test(protectedAfter)
	if err != nil {
		t.Fatalf("protected request after logout failed: %v", err)
	}
	if protectedAfterResp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("expected 401 after logout, got %d", protectedAfterResp.StatusCode)
	}

	var body map[string]any
	if err := json.NewDecoder(protectedAfterResp.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode unauthorized body: %v", err)
	}
	if body["error"] != "UNAUTHORIZED" {
		t.Fatalf("expected UNAUTHORIZED error, got %#v", body["error"])
	}
}
