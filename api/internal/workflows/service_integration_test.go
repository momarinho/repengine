package workflows

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/momarinho/rep_engine/internal/db"
)

func newIntegrationService(t *testing.T) (*Service, *pgxpool.Pool) {
	t.Helper()

	oldPool := db.Pool

	// go test can't set environment variables for the parent process, so we load .env here to get DATABASE_URL if it's not already set.
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

	repo := NewRepository(pool)
	service := NewService(repo)

	return service, pool
}

func createTestUser(t *testing.T, pool *pgxpool.Pool, prefix string) int {
	t.Helper()

	ctx := context.Background()
	email := fmt.Sprintf("%s-%d@example.com", prefix, time.Now().UnixNano())

	var userID int
	err := pool.QueryRow(ctx, `
		INSERT INTO users (email, password_hash)
		VALUES ($1, $2)
		RETURNING id
	`, email, "integration-test-hash").Scan(&userID)
	if err != nil {
		t.Fatalf("failed to create test user: %v", err)
	}

	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
	})

	return userID
}

func createWorkflowFixture(t *testing.T, pool *pgxpool.Pool, userID int) (int, time.Time) {
	t.Helper()

	ctx := context.Background()

	var workflowID int
	var updatedAt time.Time

	err := pool.QueryRow(ctx, `
		INSERT INTO workflows (user_id, name, description, is_public)
		VALUES ($1, $2, $3, $4)
		RETURNING id, updated_at
	`, userID, "Original Name", "Original Description", false).Scan(&workflowID, &updatedAt)
	if err != nil {
		t.Fatalf("failed to create workflow fixture: %v", err)
	}

	_, err = pool.Exec(ctx, `
		INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
		VALUES ($1, $2, $3, $4)
	`, workflowID, "rest", 0, []byte(`{"duration":30}`))
	if err != nil {
		t.Fatalf("failed to create workflow block fixture: %v", err)
	}

	return workflowID, updatedAt
}

func countWorkflowsByName(t *testing.T, pool *pgxpool.Pool, userID int, name string) int {
	t.Helper()

	ctx := context.Background()

	var count int
	err := pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM workflows
		WHERE user_id = $1 AND name = $2
	`, userID, name).Scan(&count)
	if err != nil {
		t.Fatalf("failed to count workflows: %v", err)
	}

	return count
}

func fetchWorkflowRow(t *testing.T, pool *pgxpool.Pool, workflowID int) (string, string, time.Time) {
	t.Helper()

	ctx := context.Background()

	var name string
	var description string
	var updatedAt time.Time

	err := pool.QueryRow(ctx, `
		SELECT name, description, updated_at
		FROM workflows
		WHERE id = $1
	`, workflowID).Scan(&name, &description, &updatedAt)
	if err != nil {
		t.Fatalf("failed to fetch workflow row: %v", err)
	}

	return name, description, updatedAt
}

func fetchWorkflowBlocks(t *testing.T, pool *pgxpool.Pool, workflowID int) []WorkflowBlock {
	t.Helper()

	ctx := context.Background()

	rows, err := pool.Query(ctx, `
		SELECT id, workflow_id, node_type_slug, position, data
		FROM workflow_blocks
		WHERE workflow_id = $1
		ORDER BY position
	`, workflowID)
	if err != nil {
		t.Fatalf("failed to query workflow blocks: %v", err)
	}
	defer rows.Close()

	var blocks []WorkflowBlock
	for rows.Next() {
		var b WorkflowBlock
		var raw []byte

		if err := rows.Scan(&b.ID, &b.WorkflowID, &b.NodeTypeSlug, &b.Position, &raw); err != nil {
			t.Fatalf("failed to scan workflow block: %v", err)
		}

		if err := json.Unmarshal(raw, &b.Data); err != nil {
			t.Fatalf("failed to unmarshal workflow block data: %v", err)
		}

		blocks = append(blocks, b)
	}

	if err := rows.Err(); err != nil {
		t.Fatalf("rows error: %v", err)
	}

	return blocks
}

func TestServiceCreateWorkflow_RollsBackWhenInsertBlocksFails(t *testing.T) {
	ctx := context.Background()
	service, pool := newIntegrationService(t)

	userID := createTestUser(t, pool, "tx-create-rollback")
	workflowName := fmt.Sprintf("tx-create-%d", time.Now().UnixNano())

	_, err := service.CreateWorkflow(ctx, CreateWorkflowInput{
		UserID:      userID,
		Name:        workflowName,
		Description: "should rollback",
		IsPublic:    false,
		Blocks: []WorkflowBlock{
			{
				// "section" has empty schema, so validation passes.
				// The failure happens later inside json.Marshal in InsertBlocksTx.
				NodeTypeSlug: "section",
				Data: map[string]any{
					"boom": make(chan int),
				},
			},
		},
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "INTERNAL_ERROR" {
		t.Fatalf("expected INTERNAL_ERROR, got %s", appErr.Code)
	}

	count := countWorkflowsByName(t, pool, userID, workflowName)
	if count != 0 {
		t.Fatalf("expected 0 persisted workflows after rollback, got %d", count)
	}
}

func TestServiceUpdateWorkflow_RollsBackWhenReplaceBlocksFails(t *testing.T) {
	ctx := context.Background()
	service, pool := newIntegrationService(t)

	userID := createTestUser(t, pool, "tx-update-rollback")
	workflowID, originalUpdatedAt := createWorkflowFixture(t, pool, userID)

	_, err := service.UpdateWorkflow(ctx, UpdateWorkflowInput{
		WorkflowID:  workflowID,
		UserID:      userID,
		Name:        "Updated Name Should Roll Back",
		Description: "Updated Description Should Roll Back",
		UpdatedAt:   originalUpdatedAt,
		Blocks: []WorkflowBlock{
			{
				// "section" has empty schema, so validation passes.
				// ReplaceBlocksTx deletes existing blocks, then json.Marshal fails.
				// The transaction must restore both the workflow row and the old block.
				NodeTypeSlug: "section",
				Data: map[string]any{
					"boom": make(chan int),
				},
			},
		},
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "INTERNAL_ERROR" {
		t.Fatalf("expected INTERNAL_ERROR, got %s", appErr.Code)
	}

	name, description, updatedAt := fetchWorkflowRow(t, pool, workflowID)

	if name != "Original Name" {
		t.Fatalf("expected workflow name to roll back to %q, got %q", "Original Name", name)
	}

	if description != "Original Description" {
		t.Fatalf("expected workflow description to roll back to %q, got %q", "Original Description", description)
	}

	if !updatedAt.Equal(originalUpdatedAt) {
		t.Fatalf("expected updated_at to remain %v, got %v", originalUpdatedAt, updatedAt)
	}

	blocks := fetchWorkflowBlocks(t, pool, workflowID)

	if len(blocks) != 1 {
		t.Fatalf("expected 1 original block after rollback, got %d", len(blocks))
	}

	if blocks[0].NodeTypeSlug != "rest" {
		t.Fatalf("expected original block node_type_slug %q, got %q", "rest", blocks[0].NodeTypeSlug)
	}

	duration, ok := blocks[0].Data["duration"]
	if !ok {
		t.Fatal("expected original block data.duration to exist after rollback")
	}

	if duration != float64(30) {
		t.Fatalf("expected original block duration 30, got %#v", duration)
	}
}
