package templates

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type dbtx interface {
	Commit(ctx context.Context) error
	Rollback(ctx context.Context) error
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults
}

type templateRepo interface {
	BeginTx(ctx context.Context) (dbtx, error)

	ListTemplates(ctx context.Context, category string, cursor int64, limit int) (PaginatedTemplates, error)
	GetTemplateByID(ctx context.Context, templateID int) (Template, error)
	ListTemplateBlocks(ctx context.Context, templateID int) ([]TemplateBlock, error)

	FindCloneJobByKey(ctx context.Context, templateID, userID int, idempotencyKey string) (CloneJob, error)
	CreateCloneJob(ctx context.Context, templateID, userID int, idempotencyKey string) (CloneJob, error)
	GetCloneJob(ctx context.Context, jobID, userID int) (CloneJob, error)
	GetCloneJobByID(ctx context.Context, jobID int) (CloneJob, error)
	MarkCloneJobRunning(ctx context.Context, jobID, attempts int) error
	MarkCloneJobFailed(ctx context.Context, jobID, attempts int, message string) error
	MarkCloneJobCompleted(ctx context.Context, jobID, workflowID int) error

	CreateWorkflowFromTemplateTx(ctx context.Context, tx dbtx, userID int, tpl Template) (int, error)
	InsertWorkflowBlocksBatchTx(ctx context.Context, tx dbtx, workflowID int, blocks []TemplateBlock) error

	GetNodeTypeSchema(ctx context.Context, slug string) (map[string]any, error)
}
