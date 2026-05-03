package templates

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

var _ templateRepo = (*Repository)(nil)

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) BeginTx(ctx context.Context) (dbtx, error) {
	return r.pool.Begin(ctx)
}

func (r *Repository) ListTemplates(ctx context.Context, category string, cursor int64, limit int) (PaginatedTemplates, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, name, description, category, is_official, author_id, metadata, created_at
		FROM templates
		WHERE is_official = TRUE
		  AND ($1 = '' OR category = $1)
		  AND ($2 = 0 OR id < $2)
		ORDER BY id DESC
		LIMIT $3
	`, category, cursor, limit+1)
	if err != nil {
		return PaginatedTemplates{}, err
	}
	defer rows.Close()

	templates := make([]Template, 0, limit+1)
	for rows.Next() {
		tpl, err := scanTemplate(rows)
		if err != nil {
			return PaginatedTemplates{}, err
		}
		templates = append(templates, tpl)
	}
	if err := rows.Err(); err != nil {
		return PaginatedTemplates{}, err
	}

	hasMore := len(templates) > limit
	var nextCursor *int64
	if hasMore {
		lastID := int64(templates[limit-1].ID)
		nextCursor = &lastID
		templates = templates[:limit]
	}

	return PaginatedTemplates{
		Data:       templates,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

func (r *Repository) GetTemplateByID(ctx context.Context, templateID int) (Template, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, name, description, category, is_official, author_id, metadata, created_at
		FROM templates
		WHERE id = $1
		  AND is_official = TRUE
	`, templateID)

	return scanTemplate(row)
}

func (r *Repository) ListTemplateBlocks(ctx context.Context, templateID int) ([]TemplateBlock, error) {
	return r.listTemplateBlocks(ctx, r.pool, templateID)
}

func (r *Repository) FindCloneJobByKey(ctx context.Context, templateID, userID int,
	idempotencyKey string) (CloneJob, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, template_id, user_id, workflow_id, idempotency_key, status, attempts,
error_message, created_at, updated_at
		FROM clone_jobs
		WHERE template_id = $1
		  AND user_id = $2
		  AND idempotency_key = $3
	`, templateID, userID, idempotencyKey)

	return scanCloneJob(row)
}

func (r *Repository) CreateCloneJob(ctx context.Context, templateID, userID int,
	idempotencyKey string) (CloneJob, error) {
	row := r.pool.QueryRow(ctx, `
		INSERT INTO clone_jobs (template_id, user_id, idempotency_key, status)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (template_id, user_id, idempotency_key)
		DO UPDATE SET updated_at = clone_jobs.updated_at
		RETURNING id, template_id, user_id, workflow_id, idempotency_key, status, attempts,
error_message, created_at, updated_at
	`, templateID, userID, idempotencyKey, CloneJobStatusPending)

	return scanCloneJob(row)
}

func (r *Repository) GetCloneJob(ctx context.Context, jobID, userID int) (CloneJob, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, template_id, user_id, workflow_id, idempotency_key, status, attempts,
error_message, created_at, updated_at
		FROM clone_jobs
		WHERE id = $1
		  AND user_id = $2
	`, jobID, userID)

	return scanCloneJob(row)
}

func (r *Repository) GetCloneJobByID(ctx context.Context, jobID int) (CloneJob, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, template_id, user_id, workflow_id, idempotency_key, status, attempts,
error_message, created_at, updated_at
		FROM clone_jobs
		WHERE id = $1
	`, jobID)

	return scanCloneJob(row)
}

func (r *Repository) MarkCloneJobRunning(ctx context.Context, jobID, attempts int) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE clone_jobs
		SET
			status = $1,
			attempts = $2,
			error_message = NULL,
			updated_at = NOW()
		WHERE id = $3
			AND (status = $4 OR status = $5)
	`, CloneJobStatusRunning, attempts, jobID, CloneJobStatusPending, CloneJobStatusFailed)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *Repository) MarkCloneJobFailed(ctx context.Context, jobID, attempts int, message string) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE clone_jobs
		SET
			status = $1,
			attempts = $2,
			error_message = $3,
			updated_at = NOW()
		WHERE id = $4
	`, CloneJobStatusFailed, attempts, message, jobID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *Repository) MarkCloneJobCompleted(ctx context.Context, jobID, workflowID int) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE clone_jobs
		SET
			status = $1,
			workflow_id = $2,
			error_message = NULL,
			updated_at = NOW()
		WHERE id = $3
		  AND status = $4
	`, CloneJobStatusCompleted, workflowID, jobID, CloneJobStatusRunning)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *Repository) CreateWorkflowFromTemplateTx(ctx context.Context, tx dbtx, userID int,
	tpl Template) (int, error) {
	var workflowID int
	err := tx.QueryRow(ctx, `
		INSERT INTO workflows (user_id, name, description, is_public)
		VALUES ($1, $2, $3, FALSE)
		RETURNING id
	`, userID, tpl.Name, tpl.Description).Scan(&workflowID)
	if err != nil {
		return 0, err
	}

	return workflowID, nil
}

func (r *Repository) InsertWorkflowBlocksBatchTx(ctx context.Context, tx dbtx, workflowID int, blocks []TemplateBlock) error {
	batch := &pgx.Batch{}

	for i, block := range blocks {
		dataJSON, err := json.Marshal(block.Data)
		if err != nil {
			return fmt.Errorf("marshal block data at position %d: %w", i, err)
		}

		batch.Queue(`
			INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
			VALUES ($1, $2, $3, $4)
		`, workflowID, block.NodeTypeSlug, i, dataJSON)
	}

	results := tx.SendBatch(ctx, batch)

	for range blocks {
		if _, err := results.Exec(); err != nil {
			_ = results.Close()
			return err
		}
	}

	if err := results.Close(); err != nil {
		return err
	}

	return nil
}

func (r *Repository) GetNodeTypeSchema(ctx context.Context, slug string) (map[string]any,
	error) {
	var raw []byte
	err := r.pool.QueryRow(ctx, `SELECT schema FROM node_types WHERE slug = $1`,
		slug).Scan(&raw)
	if err != nil {
		return nil, err
	}

	var schema map[string]any
	if err := json.Unmarshal(raw, &schema); err != nil {
		return nil, err
	}
	if schema == nil {
		schema = map[string]any{}
	}

	return schema, nil
}

type blocksQueryer interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
}

type rowScanner interface {
	Scan(dest ...any) error
}

func (r *Repository) listTemplateBlocks(ctx context.Context, q blocksQueryer, templateID int) ([]TemplateBlock, error) {
	rows, err := q.Query(ctx, `
		SELECT id, template_id, node_type_slug, position, data, created_at
		FROM template_blocks
		WHERE template_id = $1
		ORDER BY position
	`, templateID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	blocks := make([]TemplateBlock, 0)
	for rows.Next() {
		block, err := scanTemplateBlock(rows)
		if err != nil {
			return nil, err
		}
		blocks = append(blocks, block)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return blocks, nil
}

func scanTemplate(row rowScanner) (Template, error) {
	var tpl Template
	var authorID pgtype.Int4
	var metadataJSON []byte

	err := row.Scan(
		&tpl.ID,
		&tpl.Name,
		&tpl.Description,
		&tpl.Category,
		&tpl.IsOfficial,
		&authorID,
		&metadataJSON,
		&tpl.CreatedAt,
	)
	if err != nil {
		return Template{}, err
	}

	if authorID.Valid {
		id := int(authorID.Int32)
		tpl.AuthorID = &id
	}

	if err := json.Unmarshal(metadataJSON, &tpl.Metadata); err != nil {
		return Template{}, err
	}
	if tpl.Metadata == nil {
		tpl.Metadata = map[string]any{}
	}

	return tpl, nil
}

func scanTemplateBlock(row rowScanner) (TemplateBlock, error) {
	var block TemplateBlock
	var dataJSON []byte

	err := row.Scan(
		&block.ID,
		&block.TemplateID,
		&block.NodeTypeSlug,
		&block.Position,
		&dataJSON,
		&block.CreatedAt,
	)
	if err != nil {
		return TemplateBlock{}, err
	}

	if err := json.Unmarshal(dataJSON, &block.Data); err != nil {
		return TemplateBlock{}, err
	}
	if block.Data == nil {
		block.Data = map[string]any{}
	}

	return block, nil
}

func scanCloneJob(row rowScanner) (CloneJob, error) {
	var job CloneJob
	var workflowID pgtype.Int4
	var errorMessage pgtype.Text

	err := row.Scan(
		&job.ID,
		&job.TemplateID,
		&job.UserID,
		&workflowID,
		&job.IdempotencyKey,
		&job.Status,
		&job.Attempts,
		&errorMessage,
		&job.CreatedAt,
		&job.UpdatedAt,
	)
	if err != nil {
		return CloneJob{}, err
	}

	if workflowID.Valid {
		id := int(workflowID.Int32)
		job.WorkflowID = &id
	}

	if errorMessage.Valid {
		job.ErrorMessage = errorMessage.String
	}

	return job, nil
}

func IsNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}
