package workflows

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

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

type fakeRepo struct {
	beginTxFunc                        func(ctx context.Context) (dbtx, error)
	createWorkflowTxFunc               func(ctx context.Context, tx dbtx, in CreateWorkflowInput) (Workflow, error)
	insertBlocksTxFunc                 func(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) ([]WorkflowBlock, error)
	getWorkflowVisibleToUserFunc       func(ctx context.Context, workflowID, userID int) (Workflow, error)
	getOwnerAndUpdatedAtFunc           func(ctx context.Context, workflowID int) (int, time.Time, error)
	updateWorkflowIfVersionMatchesFunc func(ctx context.Context, tx dbtx, in UpdateWorkflowInput) (time.Time, error)
	workflowExistsForUserFunc          func(ctx context.Context, workflowID, userID int) (bool, error)
	replaceBlocksTxFunc                func(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) error
	getWorkflowWithBlocksTxFunc        func(ctx context.Context, tx dbtx, workflowID, userID int) (Workflow, error)
	deleteWorkflowByOwnerFunc          func(ctx context.Context, workflowID, userID int) (bool, error)
	getWorkflowOwnerFunc               func(ctx context.Context, workflowID int) (int, error)
	createVersionFunc                  func(ctx context.Context, workflowID int, commitMessage string, snapshot map[string]any) (WorkflowVersion, error)
	listVersionsFunc                   func(ctx context.Context, workflowID int, cursor int64, limit int) (PaginatedVersions, error)
	getNodeTypeSchemaFunc              func(ctx context.Context, slug string) (map[string]any, error)
	listWorkflowsFunc                  func(ctx context.Context, userID int, cursor int64, limit int) (PaginatedWorkflows, error)
}

func (f *fakeRepo) ListWorkflows(ctx context.Context, userID int, cursor int64, limit int) (PaginatedWorkflows, error) {
	if f.listWorkflowsFunc == nil {
		panic("unexpected call to ListWorkflows")
	}
	return f.listWorkflowsFunc(ctx, userID, cursor, limit)
}

func (f *fakeRepo) BeginTx(ctx context.Context) (dbtx, error) {
	if f.beginTxFunc == nil {
		panic("unexpected call to BeginTx")
	}
	return f.beginTxFunc(ctx)
}

func (f *fakeRepo) CreateWorkflowTx(ctx context.Context, tx dbtx, in CreateWorkflowInput) (Workflow, error) {
	if f.createWorkflowTxFunc == nil {
		panic("unexpected call to CreateWorkflowTx")
	}
	return f.createWorkflowTxFunc(ctx, tx, in)
}

func (f *fakeRepo) InsertBlocksTx(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) ([]WorkflowBlock, error) {
	if f.insertBlocksTxFunc == nil {
		panic("unexpected call to InsertBlocksTx")
	}
	return f.insertBlocksTxFunc(ctx, tx, workflowID, blocks)
}

func (f *fakeRepo) GetWorkflowVisibleToUser(ctx context.Context, workflowID, userID int) (Workflow, error) {
	if f.getWorkflowVisibleToUserFunc == nil {
		panic("unexpected call to GetWorkflowVisibleToUser")
	}
	return f.getWorkflowVisibleToUserFunc(ctx, workflowID, userID)
}

func (f *fakeRepo) GetOwnerAndUpdatedAt(ctx context.Context, workflowID int) (int, time.Time, error) {
	if f.getOwnerAndUpdatedAtFunc == nil {
		panic("unexpected call to GetOwnerAndUpdatedAt")
	}
	return f.getOwnerAndUpdatedAtFunc(ctx, workflowID)
}

func (f *fakeRepo) UpdateWorkflowIfVersionMatchesTx(ctx context.Context, tx dbtx, in UpdateWorkflowInput) (time.Time, error) {
	if f.updateWorkflowIfVersionMatchesFunc == nil {
		panic("unexpected call to UpdateWorkflowIfVersionMatchesTx")
	}
	return f.updateWorkflowIfVersionMatchesFunc(ctx, tx, in)
}

func (f *fakeRepo) WorkflowExistsForUser(ctx context.Context, workflowID, userID int) (bool, error) {
	if f.workflowExistsForUserFunc == nil {
		panic("unexpected call to WorkflowExistsForUser")
	}
	return f.workflowExistsForUserFunc(ctx, workflowID, userID)
}

func (f *fakeRepo) ReplaceBlocksTx(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) error {
	if f.replaceBlocksTxFunc == nil {
		panic("unexpected call to ReplaceBlocksTx")
	}
	return f.replaceBlocksTxFunc(ctx, tx, workflowID, blocks)
}

func (f *fakeRepo) GetWorkflowWithBlocksTx(ctx context.Context, tx dbtx, workflowID, userID int) (Workflow, error) {
	if f.getWorkflowWithBlocksTxFunc == nil {
		panic("unexpected call to GetWorkflowWithBlocksTx")
	}
	return f.getWorkflowWithBlocksTxFunc(ctx, tx, workflowID, userID)
}

func (f *fakeRepo) DeleteWorkflowByOwner(ctx context.Context, workflowID, userID int) (bool, error) {
	if f.deleteWorkflowByOwnerFunc == nil {
		panic("unexpected call to DeleteWorkflowByOwner")
	}
	return f.deleteWorkflowByOwnerFunc(ctx, workflowID, userID)
}

func (f *fakeRepo) GetWorkflowOwner(ctx context.Context, workflowID int) (int, error) {
	if f.getWorkflowOwnerFunc == nil {
		panic("unexpected call to GetWorkflowOwner")
	}
	return f.getWorkflowOwnerFunc(ctx, workflowID)
}

func (f *fakeRepo) CreateVersion(ctx context.Context, workflowID int, commitMessage string, snapshot map[string]any) (WorkflowVersion, error) {
	if f.createVersionFunc == nil {
		panic("unexpected call to CreateVersion")
	}
	return f.createVersionFunc(ctx, workflowID, commitMessage, snapshot)
}

func (f *fakeRepo) ListVersions(ctx context.Context, workflowID int, cursor int64, limit int) (PaginatedVersions, error) {
	if f.listVersionsFunc == nil {
		panic("unexpected call to ListVersions")
	}
	return f.listVersionsFunc(ctx, workflowID, cursor, limit)
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

func TestServiceCreateWorkflow_Success(t *testing.T) {
	ctx := context.Background()
	tx := &fakeTx{}
	now := time.Date(2026, 4, 27, 22, 0, 0, 0, time.UTC)

	repo := &fakeRepo{
		getNodeTypeSchemaFunc: func(ctx context.Context, slug string) (map[string]any, error) {
			return map[string]any{"duration": 0}, nil
		},
		beginTxFunc: func(ctx context.Context) (dbtx, error) {
			return tx, nil
		},
		createWorkflowTxFunc: func(ctx context.Context, tx dbtx, in CreateWorkflowInput) (Workflow, error) {
			return Workflow{
				ID:          1,
				UserID:      in.UserID,
				Name:        in.Name,
				Description: in.Description,
				IsPublic:    in.IsPublic,
				CreatedAt:   now,
				UpdatedAt:   now,
			}, nil
		},
		insertBlocksTxFunc: func(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) ([]WorkflowBlock, error) {
			return []WorkflowBlock{
				{
					ID:           10,
					WorkflowID:   workflowID,
					NodeTypeSlug: "rest",
					Position:     0,
					Data:         map[string]any{"duration": 30},
				},
			}, nil
		},
	}

	service := NewService(repo)

	out, err := service.CreateWorkflow(ctx, CreateWorkflowInput{
		UserID:      2,
		Name:        "Treino A",
		Description: "teste",
		IsPublic:    false,
		Blocks: []WorkflowBlock{
			{
				NodeTypeSlug: "rest",
				Data:         map[string]any{"duration": 30},
			},
		},
	})
	if err != nil {
		t.Fatalf("CreateWorkflow returned error: %v", err)
	}

	if out.ID != 1 {
		t.Fatalf("expected workflow ID 1, got %d", out.ID)
	}
	if len(out.Blocks) != 1 {
		t.Fatalf("expected 1 block, got %d", len(out.Blocks))
	}
	if tx.commitCalls != 1 {
		t.Fatalf("expected 1 commit, got %d", tx.commitCalls)
	}
}

func TestServiceCreateWorkflow_UnknownNodeType_ReturnsBlockInvalid(t *testing.T) {
	ctx := context.Background()
	beginCalled := false

	repo := &fakeRepo{
		getNodeTypeSchemaFunc: func(ctx context.Context, slug string) (map[string]any, error) {
			return nil, pgx.ErrNoRows
		},
		beginTxFunc: func(ctx context.Context) (dbtx, error) {
			beginCalled = true
			return &fakeTx{}, nil
		},
	}

	service := NewService(repo)

	_, err := service.CreateWorkflow(ctx, CreateWorkflowInput{
		UserID:      2,
		Name:        "Treino A",
		Description: "teste",
		Blocks: []WorkflowBlock{
			{
				NodeTypeSlug: "nao-existe",
				Data:         map[string]any{},
			},
		},
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "BLOCK_INVALID" {
		t.Fatalf("expected BLOCK_INVALID, got %s", appErr.Code)
	}
	if appErr.Status != 422 {
		t.Fatalf("expected status 422, got %d", appErr.Status)
	}
	if beginCalled {
		t.Fatal("BeginTx should not be called when validation fails")
	}
}

func TestServiceUpdateWorkflow_Conflict_ReturnsCurrentUpdatedAt(t *testing.T) {
	ctx := context.Background()
	current := time.Date(2026, 4, 27, 22, 29, 46, 291563000, time.UTC)

	repo := &fakeRepo{
		getOwnerAndUpdatedAtFunc: func(ctx context.Context, workflowID int) (int, time.Time, error) {
			return 2, current, nil
		},
	}

	service := NewService(repo)

	_, err := service.UpdateWorkflow(ctx, UpdateWorkflowInput{
		WorkflowID:  1,
		UserID:      2,
		Name:        "Treino A atualizado",
		Description: "teste",
		UpdatedAt:   current.Add(-time.Minute),
		Blocks:      []WorkflowBlock{},
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "CONFLICT" {
		t.Fatalf("expected CONFLICT, got %s", appErr.Code)
	}

	got, ok := appErr.Extra["current_updated_at"].(string)
	if !ok {
		t.Fatal("expected current_updated_at in error payload")
	}
	if got != current.Format(time.RFC3339Nano) {
		t.Fatalf("expected current_updated_at %q, got %q", current.Format(time.RFC3339Nano), got)
	}
}

func TestServiceUpdateWorkflow_ForDifferentOwner_ReturnsForbidden(t *testing.T) {
	ctx := context.Background()
	current := time.Date(2026, 4, 27, 22, 29, 46, 291563000, time.UTC)

	repo := &fakeRepo{
		getOwnerAndUpdatedAtFunc: func(ctx context.Context, workflowID int) (int, time.Time, error) {
			return 999, current, nil
		},
	}

	service := NewService(repo)

	_, err := service.UpdateWorkflow(ctx, UpdateWorkflowInput{
		WorkflowID:  1,
		UserID:      2,
		Name:        "Treino A atualizado",
		Description: "teste",
		UpdatedAt:   current,
		Blocks:      []WorkflowBlock{},
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "FORBIDDEN" {
		t.Fatalf("expected FORBIDDEN, got %s", appErr.Code)
	}
	if appErr.Status != 403 {
		t.Fatalf("expected status 403, got %d", appErr.Status)
	}
}

func TestServiceDeleteWorkflow_NotFound(t *testing.T) {
	ctx := context.Background()

	repo := &fakeRepo{
		deleteWorkflowByOwnerFunc: func(ctx context.Context, workflowID, userID int) (bool, error) {
			return false, nil
		},
	}

	service := NewService(repo)

	err := service.DeleteWorkflow(ctx, DeleteWorkflowInput{
		UserID:     2,
		WorkflowID: 123,
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "WORKFLOW_NOT_FOUND" {
		t.Fatalf("expected WORKFLOW_NOT_FOUND, got %s", appErr.Code)
	}
	if appErr.Status != 404 {
		t.Fatalf("expected status 404, got %d", appErr.Status)
	}
}
