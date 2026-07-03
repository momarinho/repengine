package trainingmaxes

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/momarinho/rep_engine/internal/db"
)

func newIntegrationTrainingMaxRepo(t *testing.T) (*Repository, *pgxpool.Pool) {
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

	pool := db.Pool
	ctx := context.Background()

	if err := db.RunMigrations(ctx); err != nil {
		t.Fatalf("RunMigrations failed: %v", err)
	}

	t.Cleanup(func() {
		db.Close()
		db.Pool = oldPool
	})

	return NewRepository(pool), pool
}

func createUserFixture(t *testing.T, pool *pgxpool.Pool) int {
	t.Helper()

	ctx := context.Background()
	email := fmt.Sprintf("tm-fixture-%d@example.com", time.Now().UnixNano())

	var userID int
	err := pool.QueryRow(ctx, `
		INSERT INTO users (email, password_hash)
		VALUES ($1, 'hashed-password')
		RETURNING id
	`, email).Scan(&userID)
	if err != nil {
		t.Fatalf("failed to create user fixture: %v", err)
	}

	return userID
}

func TestRepository_UpsertAndGetAndList(t *testing.T) {
	repo, pool := newIntegrationTrainingMaxRepo(t)

	userID := createUserFixture(t, pool)
	ctx := context.Background()

	// 1. Test Upsert
	tm, err := repo.UpsertTrainingMax(ctx, UpsertTrainingMaxInput{
		UserID:       userID,
		ExerciseName: "Bench Press",
		Value:        100.0,
		Unit:         "kg",
	})
	if err != nil {
		t.Fatalf("UpsertTrainingMax failed: %v", err)
	}
	if tm.UserID != userID || tm.ExerciseName != "Bench Press" || tm.Value != 100.0 || tm.Unit != "kg" {
		t.Errorf("unexpected upsert output: %+v", tm)
	}

	// 2. Test Get
	got, err := repo.GetTrainingMax(ctx, GetTrainingMaxInput{
		UserID:       userID,
		ExerciseName: "Bench Press",
	})
	if err != nil {
		t.Fatalf("GetTrainingMax failed: %v", err)
	}
	if got.ID != tm.ID || got.UserID != userID || got.ExerciseName != "Bench Press" || got.Value != 100.0 || got.Unit != "kg" {
		t.Errorf("unexpected get output: %+v", got)
	}

	// 3. Test Upsert Conflict (Update)
	updated, err := repo.UpsertTrainingMax(ctx, UpsertTrainingMaxInput{
		UserID:       userID,
		ExerciseName: "Bench Press",
		Value:        105.5,
		Unit:         "lb",
	})
	if err != nil {
		t.Fatalf("UpsertTrainingMax update failed: %v", err)
	}
	if updated.ID != tm.ID || updated.Value != 105.5 || updated.Unit != "lb" {
		t.Errorf("unexpected updated output: %+v", updated)
	}

	// 4. Test List
	_, _ = repo.UpsertTrainingMax(ctx, UpsertTrainingMaxInput{
		UserID:       userID,
		ExerciseName: "Squat",
		Value:        140.0,
		Unit:         "kg",
	})

	list, err := repo.ListTrainingMaxes(ctx, ListTrainingMaxesInput{
		UserID: userID,
	})
	if err != nil {
		t.Fatalf("ListTrainingMaxes failed: %v", err)
	}
	if len(list) != 2 {
		t.Errorf("expected 2 training maxes, got %d", len(list))
	}
}
