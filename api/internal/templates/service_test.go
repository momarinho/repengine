package templates

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

type fakeBatchResults struct{}

func (f *fakeBatchResults) Exec() (pgconn.CommandTag, error) { return pgconn.CommandTag{}, nil }
func (f *fakeBatchResults) Query() (pgx.Rows, error)         { return nil, nil }
func (f *fakeBatchResults) QueryRow() pgx.Row                { return nil }
func (f *fakeBatchResults) Close() error                     { return nil }

type fakeTx struct {
	commitCalls   int
	rollbackCalls int
}

func (f *fakeTx) Commit(ctx context.Context) error {
	f.commitCalls++
	return nil
}

func (f *fakeTx) Rollback(ctx context.Context) error {
	f.rollbackCalls++
	return nil
}

func (f *fakeTx) Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error) {
	return pgconn.CommandTag{}, nil
}

func (f *fakeTx) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
	return nil, nil
}

func (f *fakeTx) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
	return nil
}

func (f *fakeTx) SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults {
	return &fakeBatchResults{}
}

type fakeRepo struct {
	beginTxFunc                      func(ctx context.Context) (dbtx, error)
	listTemplatesFunc                func(ctx context.Context, category string, cursor int64, limit int) (PaginatedTemplates, error)
	getTemplateByIDFunc              func(ctx context.Context, templateID int) (Template, error)
	listTemplateBlocksFunc           func(ctx context.Context, templateID int) ([]TemplateBlock, error)
	findCloneJobByKeyFunc            func(ctx context.Context, templateID, userID int, key string) (CloneJob, error)
	createCloneJobFunc               func(ctx context.Context, templateID, userID int, key string) (CloneJob, error)
	getCloneJobFunc                  func(ctx context.Context, jobID, userID int) (CloneJob, error)
	getCloneJobByIDFunc              func(ctx context.Context, jobID int) (CloneJob, error)
	markCloneJobRunningFunc          func(ctx context.Context, jobID, attempts int) error
	markCloneJobFailedFunc           func(ctx context.Context, jobID, attempts int, message string) error
	markCloneJobCompletedFunc        func(ctx context.Context, jobID, workflowID int) error
	createWorkflowFromTemplateTxFunc func(ctx context.Context, tx dbtx, userID int, tpl Template) (int, error)
	insertWorkflowBlocksBatchTxFunc  func(ctx context.Context, tx dbtx, workflowID int, blocks []TemplateBlock) error
	getNodeTypeSchemaFunc            func(ctx context.Context, slug string) (map[string]any, error)
}

func (f *fakeRepo) BeginTx(ctx context.Context) (dbtx, error) {
	if f.beginTxFunc == nil {
		panic("unexpected call to BeginTx")
	}
	return f.beginTxFunc(ctx)
}

func (f *fakeRepo) ListTemplates(ctx context.Context, category string, cursor int64, limit int) (PaginatedTemplates, error) {
	if f.listTemplatesFunc == nil {
		panic("unexpected call to ListTemplates")
	}
	return f.listTemplatesFunc(ctx, category, cursor, limit)
}

func (f *fakeRepo) GetTemplateByID(ctx context.Context, templateID int) (Template, error) {
	if f.getTemplateByIDFunc == nil {
		panic("unexpected call to GetTemplateByID")
	}
	return f.getTemplateByIDFunc(ctx, templateID)
}

func (f *fakeRepo) ListTemplateBlocks(ctx context.Context, templateID int) ([]TemplateBlock, error) {
	if f.listTemplateBlocksFunc == nil {
		panic("unexpected call to ListTemplateBlocks")
	}
	return f.listTemplateBlocksFunc(ctx, templateID)
}

func (f *fakeRepo) FindCloneJobByKey(ctx context.Context, templateID, userID int, key string) (CloneJob, error) {
	if f.findCloneJobByKeyFunc == nil {
		panic("unexpected call to FindCloneJobByKey")
	}
	return f.findCloneJobByKeyFunc(ctx, templateID, userID, key)
}

func (f *fakeRepo) CreateCloneJob(ctx context.Context, templateID, userID int, key string) (CloneJob, error) {
	if f.createCloneJobFunc == nil {
		panic("unexpected call to CreateCloneJob")
	}
	return f.createCloneJobFunc(ctx, templateID, userID, key)
}

func (f *fakeRepo) GetCloneJob(ctx context.Context, jobID, userID int) (CloneJob, error) {
	if f.getCloneJobFunc == nil {
		panic("unexpected call to GetCloneJob")
	}
	return f.getCloneJobFunc(ctx, jobID, userID)
}

func (f *fakeRepo) GetCloneJobByID(ctx context.Context, jobID int) (CloneJob, error) {
	if f.getCloneJobByIDFunc == nil {
		panic("unexpected call to GetCloneJobByID")
	}
	return f.getCloneJobByIDFunc(ctx, jobID)
}

func (f *fakeRepo) MarkCloneJobRunning(ctx context.Context, jobID, attempts int) error {
	if f.markCloneJobRunningFunc == nil {
		panic("unexpected call to MarkCloneJobRunning")
	}
	return f.markCloneJobRunningFunc(ctx, jobID, attempts)
}

func (f *fakeRepo) MarkCloneJobFailed(ctx context.Context, jobID, attempts int, message string) error {
	if f.markCloneJobFailedFunc == nil {
		panic("unexpected call to MarkCloneJobFailed")
	}
	return f.markCloneJobFailedFunc(ctx, jobID, attempts, message)
}

func (f *fakeRepo) MarkCloneJobCompleted(ctx context.Context, jobID, workflowID int) error {
	if f.markCloneJobCompletedFunc == nil {
		panic("unexpected call to MarkCloneJobCompleted")
	}
	return f.markCloneJobCompletedFunc(ctx, jobID, workflowID)
}

func (f *fakeRepo) CreateWorkflowFromTemplateTx(ctx context.Context, tx dbtx, userID int, tpl Template) (int, error) {
	if f.createWorkflowFromTemplateTxFunc == nil {
		panic("unexpected call to CreateWorkflowFromTemplateTx")
	}
	return f.createWorkflowFromTemplateTxFunc(ctx, tx, userID, tpl)
}

func (f *fakeRepo) InsertWorkflowBlocksBatchTx(ctx context.Context, tx dbtx, workflowID int, blocks []TemplateBlock) error {
	if f.insertWorkflowBlocksBatchTxFunc == nil {
		panic("unexpected call to InsertWorkflowBlocksBatchTx")
	}
	return f.insertWorkflowBlocksBatchTxFunc(ctx, tx, workflowID, blocks)
}

func (f *fakeRepo) GetNodeTypeSchema(ctx context.Context, slug string) (map[string]any, error) {
	if f.getNodeTypeSchemaFunc == nil {
		panic("unexpected call to GetNodeTypeSchema")
	}
	return f.getNodeTypeSchemaFunc(ctx, slug)
}

func requireAppError(t *testing.T, err error) *apperrors.AppError {
	t.Helper()

	if err == nil {
		t.Fatal("expected error, got nil")
	}

	var appErr *apperrors.AppError
	if !errors.As(err, &appErr) {
		t.Fatalf("expected *AppError, got %T", err)
	}

	return appErr
}

func completedWorker() *CloneWorker {
	repo := &fakeRepo{
		getCloneJobByIDFunc: func(ctx context.Context, jobID int) (CloneJob, error) {
			return CloneJob{ID: jobID, Status: CloneJobStatusCompleted}, nil
		},
	}
	return &CloneWorker{repo: repo, maxAttempts: 3}
}

func TestServiceListTemplates_FilterByCategory(t *testing.T) {
	ctx := context.Background()

	var gotCategory string
	var gotLimit int

	repo := &fakeRepo{
		listTemplatesFunc: func(ctx context.Context, category string, cursor int64, limit int) (PaginatedTemplates, error) {
			gotCategory = category
			gotLimit = limit
			return PaginatedTemplates{
				Data: []Template{{ID: 1, Name: "5/3/1", Category: "strength"}},
			}, nil
		},
	}

	service := NewService(repo, nil)

	out, err := service.ListTemplates(ctx, ListTemplatesInput{
		Category: " strength ",
		Limit:    200,
	})
	if err != nil {
		t.Fatalf("ListTemplates returned error: %v", err)
	}

	if gotCategory != "strength" {
		t.Fatalf("expected trimmed category %q, got %q", "strength", gotCategory)
	}
	if gotLimit != 100 {
		t.Fatalf("expected limit 100, got %d", gotLimit)
	}
	if len(out.Data) != 1 {
		t.Fatalf("expected 1 template, got %d", len(out.Data))
	}
}

func TestServiceGetTemplate_NotFound(t *testing.T) {
	ctx := context.Background()

	repo := &fakeRepo{
		getTemplateByIDFunc: func(ctx context.Context, templateID int) (Template, error) {
			return Template{}, pgx.ErrNoRows
		},
	}

	service := NewService(repo, nil)

	_, err := service.GetTemplate(ctx, GetTemplateInput{
		UserID:     1,
		TemplateID: 999,
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "TEMPLATE_NOT_FOUND" {
		t.Fatalf("expected TEMPLATE_NOT_FOUND, got %s", appErr.Code)
	}
}

func TestWorkerProcessCloneJob_FailsThreeTimesAndStoresErrorMessage(t *testing.T) {
	ctx := context.Background()

	var runningAttempts []int
	var failedAttempts int
	var failedMessage string

	repo := &fakeRepo{
		getCloneJobByIDFunc: func(ctx context.Context, jobID int) (CloneJob, error) {
			return CloneJob{
				ID:         jobID,
				TemplateID: 55,
				UserID:     9,
				Status:     CloneJobStatusPending,
			}, nil
		},
		markCloneJobRunningFunc: func(ctx context.Context, jobID, attempts int) error {
			runningAttempts = append(runningAttempts, attempts)
			return nil
		},
		getTemplateByIDFunc: func(ctx context.Context, templateID int) (Template, error) {
			return Template{}, errors.New("boom loading template")
		},
		markCloneJobFailedFunc: func(ctx context.Context, jobID, attempts int, message string) error {
			failedAttempts = attempts
			failedMessage = message
			return nil
		},
	}

	worker := NewCloneWorker(repo)
	worker.ProcessCloneJob(ctx, 77)

	if len(runningAttempts) != 3 {
		t.Fatalf("expected 3 attempts, got %d", len(runningAttempts))
	}
	if failedAttempts != 3 {
		t.Fatalf("expected failed attempts=3, got %d", failedAttempts)
	}
	if !strings.Contains(failedMessage, "get template") {
		t.Fatalf("expected error message to mention get template, got %q", failedMessage)
	}
}

func TestServiceCloneTemplate_ReturnsExistingJobForSameIdempotencyKey(t *testing.T) {
	ctx := context.Background()

	existing := CloneJob{
		ID:             12,
		TemplateID:     1,
		UserID:         2,
		IdempotencyKey: "same-key",
		Status:         CloneJobStatusPending,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}

	repo := &fakeRepo{
		getTemplateByIDFunc: func(ctx context.Context, templateID int) (Template, error) {
			return Template{ID: templateID, Name: "5/3/1"}, nil
		},
		findCloneJobByKeyFunc: func(ctx context.Context, templateID, userID int, key string) (CloneJob, error) {
			return existing, nil
		},
		createCloneJobFunc: func(ctx context.Context, templateID, userID int, key string) (CloneJob, error) {
			t.Fatal("CreateCloneJob should not be called when job already exists")
			return CloneJob{}, nil
		},
	}

	service := NewService(repo, completedWorker())

	out, err := service.CloneTemplate(ctx, CloneTemplateInput{
		UserID:         2,
		TemplateID:     1,
		IdempotencyKey: "same-key",
	})
	if err != nil {
		t.Fatalf("CloneTemplate returned error: %v", err)
	}

	if out.ID != existing.ID {
		t.Fatalf("expected existing job ID %d, got %d", existing.ID, out.ID)
	}
}
