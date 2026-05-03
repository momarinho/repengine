package templates

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

func newIntegrationTemplateDeps(t *testing.T) (*Service, *Repository, *pgxpool.Pool) {
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

	if err := db.SeedTemplates(ctx); err != nil {
		t.Fatalf("SeedTemplates failed: %v", err)
	}

	t.Cleanup(func() {
		db.Close()
		db.Pool = oldPool
	})

	repo := NewRepository(pool)
	worker := NewCloneWorker(repo)
	service := NewService(repo, worker)

	return service, repo, pool
}

func createTemplateTestUser(t *testing.T, pool *pgxpool.Pool, prefix string) int {
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

func templateIDByName(t *testing.T, pool *pgxpool.Pool, name string) int {
	t.Helper()

	var templateID int
	err := pool.QueryRow(context.Background(), `
		SELECT id
		FROM templates
		WHERE name = $1
		  AND is_official = TRUE
		LIMIT 1
	`, name).Scan(&templateID)
	if err != nil {
		t.Fatalf("failed to load template id: %v", err)
	}

	return templateID
}

func waitForCloneJobFinalState(t *testing.T, repo *Repository, jobID int, timeout time.Duration) CloneJob {
	t.Helper()

	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		job, err := repo.GetCloneJobByID(context.Background(), jobID)
		if err != nil {
			t.Fatalf("failed to get clone job: %v", err)
		}

		if job.Status == CloneJobStatusCompleted || job.Status == CloneJobStatusFailed {
			return job
		}

		time.Sleep(25 * time.Millisecond)
	}

	t.Fatalf("timed out waiting for clone job %d final state", jobID)
	return CloneJob{}
}

func countCloneJobsByKey(t *testing.T, pool *pgxpool.Pool, templateID, userID int, key string) int {
	t.Helper()

	var count int
	err := pool.QueryRow(context.Background(), `
		SELECT COUNT(*)
		FROM clone_jobs
		WHERE template_id = $1
		  AND user_id = $2
		  AND idempotency_key = $3
	`, templateID, userID, key).Scan(&count)
	if err != nil {
		t.Fatalf("failed to count clone jobs: %v", err)
	}

	return count
}

func countUserWorkflowsByName(t *testing.T, pool *pgxpool.Pool, userID int, name string) int {
	t.Helper()

	var count int
	err := pool.QueryRow(context.Background(), `
		SELECT COUNT(*)
		FROM workflows
		WHERE user_id = $1
		  AND name = $2
	`, userID, name).Scan(&count)
	if err != nil {
		t.Fatalf("failed to count workflows: %v", err)
	}

	return count
}

func TestServiceCloneTemplate_CompletesAndFillsWorkflowID(t *testing.T) {
	ctx := context.Background()
	service, repo, pool := newIntegrationTemplateDeps(t)

	userID := createTemplateTestUser(t, pool, "clone-complete")
	templateID := templateIDByName(t, pool, "5/3/1")

	job, err := service.CloneTemplate(ctx, CloneTemplateInput{
		UserID:         userID,
		TemplateID:     templateID,
		IdempotencyKey: fmt.Sprintf("clone-complete-%d", time.Now().UnixNano()),
	})
	if err != nil {
		t.Fatalf("CloneTemplate returned error: %v", err)
	}

	if job.ID == 0 {
		t.Fatal("expected non-zero job ID")
	}

	finalJob := waitForCloneJobFinalState(t, repo, job.ID, 5*time.Second)

	if finalJob.Status != CloneJobStatusCompleted {
		t.Fatalf("expected completed status, got %q", finalJob.Status)
	}
	if finalJob.WorkflowID == nil {
		t.Fatal("expected workflow_id to be filled")
	}
}

func TestServiceCloneTemplate_SameIdempotencyKeyDoesNotDuplicate(t *testing.T) {
	ctx := context.Background()
	service, repo, pool := newIntegrationTemplateDeps(t)

	userID := createTemplateTestUser(t, pool, "clone-idempotent")
	templateID := templateIDByName(t, pool, "GZCLP")
	key := fmt.Sprintf("same-key-%d", time.Now().UnixNano())

	job1, err := service.CloneTemplate(ctx, CloneTemplateInput{
		UserID:         userID,
		TemplateID:     templateID,
		IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("first CloneTemplate returned error: %v", err)
	}

	job2, err := service.CloneTemplate(ctx, CloneTemplateInput{
		UserID:         userID,
		TemplateID:     templateID,
		IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("second CloneTemplate returned error: %v", err)
	}

	if job1.ID != job2.ID {
		t.Fatalf("expected same job ID for same idempotency key, got %d and %d", job1.ID, job2.ID)
	}

	finalJob := waitForCloneJobFinalState(t, repo, job1.ID, 5*time.Second)
	if finalJob.Status != CloneJobStatusCompleted {
		t.Fatalf("expected completed status, got %q", finalJob.Status)
	}

	if got := countCloneJobsByKey(t, pool, templateID, userID, key); got != 1 {
		t.Fatalf("expected 1 clone job, got %d", got)
	}

	if got := countUserWorkflowsByName(t, pool, userID, "GZCLP"); got != 1 {
		t.Fatalf("expected 1 workflow cloned for user, got %d", got)
	}
}
