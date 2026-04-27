package workflows

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type dbtx interface {
	Commit(ctx context.Context) error
	Rollback(ctx context.Context) error
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type workflowRepo interface {
	ListWorkflows(ctx context.Context, userID int, cursor int64, limit int) (PaginatedWorkflows, error)
	BeginTx(ctx context.Context) (dbtx, error)

	CreateWorkflowTx(ctx context.Context, tx dbtx, in CreateWorkflowInput) (Workflow, error)
	InsertBlocksTx(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) ([]WorkflowBlock, error)

	GetWorkflowVisibleToUser(ctx context.Context, workflowID, userID int) (Workflow, error)
	GetOwnerAndUpdatedAt(ctx context.Context, workflowID int) (int, time.Time, error)
	UpdateWorkflowIfVersionMatchesTx(ctx context.Context, tx dbtx, in UpdateWorkflowInput) (time.Time, error)
	WorkflowExistsForUser(ctx context.Context, workflowID, userID int) (bool, error)
	ReplaceBlocksTx(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) error
	GetWorkflowWithBlocksTx(ctx context.Context, tx dbtx, workflowID, userID int) (Workflow, error)

	DeleteWorkflowByOwner(ctx context.Context, workflowID, userID int) (bool, error)

	GetWorkflowOwner(ctx context.Context, workflowID int) (int, error)
	CreateVersion(ctx context.Context, workflowID int, commitMessage string, snapshot map[string]any) (WorkflowVersion, error)
	ListVersions(ctx context.Context, workflowID int, cursor int64, limit int) (PaginatedVersions, error)

	GetNodeTypeSchema(ctx context.Context, slug string) (map[string]any, error)
}

var _ workflowRepo = (*Repository)(nil)
