package workoutsessions

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

func newIntegrationWorkoutSessionRepo(t *testing.T) (*Repository, *pgxpool.Pool) {
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

func createWorkoutSessionFixture(t *testing.T, pool *pgxpool.Pool) (userID, workflowID, workflowBlockID, sessionID int) {
	t.Helper()

	ctx := context.Background()
	email := fmt.Sprintf("log-fixture-%d@example.com", time.Now().UnixNano())

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
	`, userID, "Fixture Workflow", "fixture").Scan(&workflowID); err != nil {
		t.Fatalf("create workflow: %v", err)
	}

	if err := pool.QueryRow(ctx, `
		INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
		VALUES ($1, 'wave', 0, '{}'::jsonb)
		RETURNING id
	`, workflowID).Scan(&workflowBlockID); err != nil {
		t.Fatalf("create workflow block: %v", err)
	}

	if err := pool.QueryRow(ctx, `
		INSERT INTO workout_sessions (workflow_id, user_id, section_id, section_title, status)
		VALUES ($1, $2, 'section-1', 'Section 1', 'active')
		RETURNING id
	`, workflowID, userID).Scan(&sessionID); err != nil {
		t.Fatalf("create workout session: %v", err)
	}

	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
	})

	return userID, workflowID, workflowBlockID, sessionID
}

func TestRepositoryInsertSetLog_AcceptsWorkflowBlockID(t *testing.T) {
	repo, pool := newIntegrationWorkoutSessionRepo(t)
	userID, _, workflowBlockID, sessionID := createWorkoutSessionFixture(t, pool)

	log, err := repo.InsertSetLog(context.Background(), InsertSetLogInput{
		UserID:              userID,
		SessionID:           sessionID,
		WorkflowBlockID:     &workflowBlockID,
		BlockClientID:       fmt.Sprintf("block-%d", workflowBlockID),
		NodeTypeSlug:        "wave",
		SetIndex:            1,
		PrescribedReps:      "5",
		PrescribedIntensity: "65",
		PrescribedRPE:       "7",
		ActualReps:          "5",
		ActualLoad:          "100",
		ActualRPE:           "7",
		Completed:           true,
	})
	if err != nil {
		t.Fatalf("InsertSetLog with workflow block ID failed: %v", err)
	}

	if log.WorkflowBlockID == nil || *log.WorkflowBlockID != workflowBlockID {
		t.Fatalf("expected workflow_block_id %d, got %+v", workflowBlockID, log.WorkflowBlockID)
	}
}

func TestRepositoryInsertSetLog_AcceptsNilWorkflowBlockID(t *testing.T) {
	repo, pool := newIntegrationWorkoutSessionRepo(t)
	userID, _, _, sessionID := createWorkoutSessionFixture(t, pool)

	log, err := repo.InsertSetLog(context.Background(), InsertSetLogInput{
		UserID:              userID,
		SessionID:           sessionID,
		WorkflowBlockID:     nil,
		BlockClientID:       "nil-block-id",
		NodeTypeSlug:        "wave",
		SetIndex:            1,
		PrescribedReps:      "5",
		PrescribedIntensity: "65",
		PrescribedRPE:       "7",
		ActualReps:          "5",
		ActualLoad:          "100",
		ActualRPE:           "7",
		Completed:           true,
	})
	if err != nil {
		t.Fatalf("InsertSetLog with nil workflow block ID failed: %v", err)
	}

	if log.WorkflowBlockID != nil {
		t.Fatalf("expected nil workflow_block_id, got %+v", log.WorkflowBlockID)
	}
}
