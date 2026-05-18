package progressionstates

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

func newIntegrationProgressionStateRepo(t *testing.T) (*Repository, *pgxpool.Pool) {
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

	if err := db.SeedNodeTypes(ctx); err != nil {
		t.Fatalf("SeedNodeTypes failed: %v", err)
	}

	t.Cleanup(func() {
		db.Close()
		db.Pool = oldPool
	})

	return NewRepository(pool), pool
}

func createProgressionStateFixture(t *testing.T, pool *pgxpool.Pool) (userID, workflowID, workflowBlockID int) {
	t.Helper()

	ctx := context.Background()
	email := fmt.Sprintf("progression-fixture-%d@example.com", time.Now().UnixNano())

	if err := pool.QueryRow(ctx, `
		INSERT INTO users (email, password_hash)
		VALUES ($1, $2)
		RETURNING id
	`, email, "integration-test-hash").Scan(&userID); err != nil {
		t.Fatalf("create user: %v", err)
	}

	if err := pool.QueryRow(ctx, `
		INSERT INTO workflows (user_id, name, description, is_public)
		VALUES ($1, $2, $3, FALSE)
		RETURNING id
	`, userID, "Progression Fixture", "fixture").Scan(&workflowID); err != nil {
		t.Fatalf("create workflow: %v", err)
	}

	if err := pool.QueryRow(ctx, `
		INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
		VALUES ($1, 'linear_progression', 0, '{}'::jsonb)
		RETURNING id
	`, workflowID).Scan(&workflowBlockID); err != nil {
		t.Fatalf("create workflow block: %v", err)
	}

	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
	})

	return userID, workflowID, workflowBlockID
}

func TestRepositoryUpsertProgressionState_PopulatesCanonicalNumericColumns(t *testing.T) {
	repo, pool := newIntegrationProgressionStateRepo(t)
	userID, workflowID, workflowBlockID := createProgressionStateFixture(t, pool)

	state, err := repo.UpsertProgressionState(context.Background(), UpsertProgressionStateInput{
		UserID:                   userID,
		WorkflowID:               workflowID,
		WorkflowBlockID:          workflowBlockID,
		BlockKey:                 "day-1::linear_progression::squat::1",
		NodeTypeSlug:             "linear_progression",
		StateType:                StateTypeLinear,
		ExerciseName:             "Squat",
		Outcome:                  OutcomeIncrease,
		CurrentLoad:              "100 kg",
		SuggestedLoad:            "102.5 kg",
		AvgActualRPE:             "8.5",
		AvgActualRIR:             "1.5",
		LastLogCount:             3,
		Summary:                  "Add load next session.",
		SuggestedIntensityOffset: "-2.5",
		Metadata:                 map[string]any{"load_unit": "kg"},
	})
	if err != nil {
		t.Fatalf("UpsertProgressionState failed: %v", err)
	}

	var currentLoadValue, suggestedLoadValue, suggestedOffsetValue, avgRPEValue, avgRIRValue float64
	if err := pool.QueryRow(context.Background(), `
		SELECT
			current_load_value,
			suggested_load_value,
			suggested_intensity_offset_value,
			avg_actual_rpe_value,
			avg_actual_rir_value
		FROM progression_states
		WHERE id = $1
	`, state.ID).Scan(
		&currentLoadValue,
		&suggestedLoadValue,
		&suggestedOffsetValue,
		&avgRPEValue,
		&avgRIRValue,
	); err != nil {
		t.Fatalf("query canonical progression values: %v", err)
	}

	if currentLoadValue != 100 {
		t.Fatalf("expected current_load_value 100, got %v", currentLoadValue)
	}
	if suggestedLoadValue != 102.5 {
		t.Fatalf("expected suggested_load_value 102.5, got %v", suggestedLoadValue)
	}
	if suggestedOffsetValue != -2.5 {
		t.Fatalf("expected suggested_intensity_offset_value -2.5, got %v", suggestedOffsetValue)
	}
	if avgRPEValue != 8.5 {
		t.Fatalf("expected avg_actual_rpe_value 8.5, got %v", avgRPEValue)
	}
	if avgRIRValue != 1.5 {
		t.Fatalf("expected avg_actual_rir_value 1.5, got %v", avgRIRValue)
	}
}
