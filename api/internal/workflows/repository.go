package workflows

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) BeginTx(ctx context.Context) (dbtx, error) {
	return r.pool.Begin(ctx)
}

func (r *Repository) ListWorkflows(ctx context.Context, userID int, cursor int64, limit int) (PaginatedWorkflows, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, name, description, is_public, created_at, updated_at
		FROM workflows
		WHERE user_id = $1 AND ($2 = 0 OR id < $2)
		ORDER BY id DESC
		LIMIT $3
	`, userID, cursor, limit+1)
	if err != nil {
		return PaginatedWorkflows{}, err
	}
	defer rows.Close()

	workflows := make([]Workflow, 0, limit+1)
	for rows.Next() {
		var w Workflow
		if err := rows.Scan(&w.ID, &w.UserID, &w.Name, &w.Description, &w.IsPublic, &w.CreatedAt, &w.UpdatedAt); err != nil {
			return PaginatedWorkflows{}, err
		}
		workflows = append(workflows, w)
	}
	if err := rows.Err(); err != nil {
		return PaginatedWorkflows{}, err
	}

	hasMore := len(workflows) > limit
	var nextCursor *int64
	if hasMore {
		lastID := int64(workflows[limit-1].ID)
		nextCursor = &lastID
		workflows = workflows[:limit]
	}

	return PaginatedWorkflows{
		Data:       workflows,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

func (r *Repository) CreateWorkflowTx(ctx context.Context, tx dbtx, in CreateWorkflowInput) (Workflow, error) {
	var workflow Workflow
	err := tx.QueryRow(ctx, `
		INSERT INTO workflows (user_id, name, description, is_public)
		VALUES ($1, $2, $3, $4)
		RETURNING id, user_id, name, description, is_public, created_at, updated_at
	`, in.UserID, in.Name, in.Description, in.IsPublic).Scan(
		&workflow.ID,
		&workflow.UserID,
		&workflow.Name,
		&workflow.Description,
		&workflow.IsPublic,
		&workflow.CreatedAt,
		&workflow.UpdatedAt,
	)
	if err != nil {
		return Workflow{}, err
	}

	return workflow, nil
}

func (r *Repository) InsertBlocksTx(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) ([]WorkflowBlock, error) {
	inserted := make([]WorkflowBlock, 0, len(blocks))
	for i, block := range blocks {
		dataJSON, err := json.Marshal(block.Data)
		if err != nil {
			return nil, fmt.Errorf("marshal block data: %w", err)
		}

		var blockID int
		err = tx.QueryRow(ctx, `
			INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
			VALUES ($1, $2, $3, $4)
			RETURNING id
		`, workflowID, block.NodeTypeSlug, i, dataJSON).Scan(&blockID)
		if err != nil {
			return nil, err
		}

		inserted = append(inserted, WorkflowBlock{
			ID:           blockID,
			WorkflowID:   workflowID,
			NodeTypeSlug: block.NodeTypeSlug,
			Position:     i,
			Data:         block.Data,
		})
	}

	return inserted, nil
}

func (r *Repository) GetOwnerAndUpdatedAt(ctx context.Context, workflowID int) (int, time.Time, error) {
	var ownerID int
	var updatedAt time.Time
	err := r.pool.QueryRow(ctx, `SELECT user_id, updated_at FROM workflows WHERE id = $1`, workflowID).Scan(&ownerID, &updatedAt)
	if err != nil {
		return 0, time.Time{}, err
	}

	return ownerID, updatedAt, nil
}

func (r *Repository) UpdateWorkflowIfVersionMatchesTx(
	ctx context.Context,
	tx dbtx,
	in UpdateWorkflowInput,
) (time.Time, error) {
	var newUpdatedAt time.Time
	err := tx.QueryRow(ctx, `
		UPDATE workflows
		SET
			name = $1,
			description = $2,
			is_public = COALESCE($3, is_public),
			updated_at = NOW()
		WHERE id = $4
		  AND user_id = $5
		  AND updated_at = $6
		RETURNING updated_at
	`, in.Name, in.Description, in.IsPublic, in.WorkflowID, in.UserID, in.UpdatedAt).Scan(&newUpdatedAt)
	if err != nil {
		return time.Time{}, err
	}

	return newUpdatedAt, nil
}

func (r *Repository) ReplaceBlocksTx(ctx context.Context, tx dbtx, workflowID int, blocks []WorkflowBlock) error {
	if _, err := tx.Exec(ctx, `DELETE FROM workflow_blocks WHERE workflow_id = $1`, workflowID); err != nil {
		return err
	}

	for i, block := range blocks {
		dataJSON, err := json.Marshal(block.Data)
		if err != nil {
			return fmt.Errorf("marshal block data: %w", err)
		}

		if _, err := tx.Exec(ctx, `
			INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
			VALUES ($1, $2, $3, $4)
		`, workflowID, block.NodeTypeSlug, i, dataJSON); err != nil {
			return err
		}
	}

	return nil
}

func (r *Repository) GetWorkflowWithBlocksTx(ctx context.Context, tx dbtx, workflowID, userID int) (Workflow, error) {
	var w Workflow
	err := tx.QueryRow(ctx, `
		SELECT id, user_id, name, description, is_public, created_at, updated_at
		FROM workflows
		WHERE id = $1 AND user_id = $2
	`, workflowID, userID).Scan(
		&w.ID, &w.UserID, &w.Name, &w.Description, &w.IsPublic, &w.CreatedAt, &w.UpdatedAt,
	)
	if err != nil {
		return Workflow{}, err
	}

	blocks, err := r.listBlocksForWorkflow(ctx, tx, workflowID)
	if err != nil {
		return Workflow{}, err
	}
	w.Blocks = blocks

	return w, nil
}

func (r *Repository) GetWorkflowVisibleToUser(ctx context.Context, workflowID, userID int) (Workflow, error) {
	var w Workflow
	err := r.pool.QueryRow(ctx, `
		SELECT id, user_id, name, description, is_public, created_at, updated_at
		FROM workflows
		WHERE id = $1 AND (user_id = $2 OR is_public = true)
	`, workflowID, userID).Scan(
		&w.ID, &w.UserID, &w.Name, &w.Description, &w.IsPublic, &w.CreatedAt, &w.UpdatedAt,
	)
	if err != nil {
		return Workflow{}, err
	}

	blocks, err := r.listBlocksForWorkflow(ctx, r.pool, workflowID)
	if err != nil {
		return Workflow{}, err
	}
	w.Blocks = blocks

	return w, nil
}

func (r *Repository) DeleteWorkflowByOwner(ctx context.Context, workflowID, userID int) (bool, error) {
	result, err := r.pool.Exec(ctx, `DELETE FROM workflows WHERE id = $1 AND user_id = $2`, workflowID, userID)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}

func (r *Repository) GetWorkflowOwner(ctx context.Context, workflowID int) (int, error) {
	var userID int
	err := r.pool.QueryRow(ctx, `SELECT user_id FROM workflows WHERE id = $1`, workflowID).Scan(&userID)
	if err != nil {
		return 0, err
	}
	return userID, nil
}

func (r *Repository) WorkflowExistsForUser(ctx context.Context, workflowID, userID int) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM workflows WHERE id = $1 AND user_id = $2
		)
	`, workflowID, userID).Scan(&exists)
	return exists, err
}

func (r *Repository) CreateVersion(ctx context.Context, workflowID int, commitMessage string, snapshot map[string]any) (WorkflowVersion, error) {
	snapshotJSON, err := json.Marshal(snapshot)
	if err != nil {
		return WorkflowVersion{}, err
	}

	var version WorkflowVersion
	err = r.pool.QueryRow(ctx, `
		INSERT INTO workflow_versions (workflow_id, version_number, snapshot, commit_message)
		SELECT $1, COALESCE(MAX(version_number), 0) + 1, $2, $3
		FROM workflow_versions
		WHERE workflow_id = $1
		RETURNING id, workflow_id, version_number, snapshot, commit_message, created_at
	`, workflowID, snapshotJSON, commitMessage).Scan(
		&version.ID,
		&version.WorkflowID,
		&version.VersionNumber,
		&snapshotJSON,
		&version.CommitMessage,
		&version.CreatedAt,
	)
	if err != nil {
		return WorkflowVersion{}, err
	}
	if err := json.Unmarshal(snapshotJSON, &version.Snapshot); err != nil {
		return WorkflowVersion{}, err
	}

	return version, nil
}

func (r *Repository) ListVersions(ctx context.Context, workflowID int, cursor int64, limit int) (PaginatedVersions, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, workflow_id, version_number, snapshot, commit_message, created_at
		FROM workflow_versions
		WHERE workflow_id = $1 AND ($2 = 0 OR id < $2)
		ORDER BY version_number DESC
		LIMIT $3
	`, workflowID, cursor, limit+1)
	if err != nil {
		return PaginatedVersions{}, err
	}
	defer rows.Close()

	versions := make([]WorkflowVersion, 0, limit+1)
	for rows.Next() {
		var v WorkflowVersion
		var snapshotJSON []byte
		if err := rows.Scan(&v.ID, &v.WorkflowID, &v.VersionNumber, &snapshotJSON, &v.CommitMessage, &v.CreatedAt); err != nil {
			return PaginatedVersions{}, err
		}
		if err := json.Unmarshal(snapshotJSON, &v.Snapshot); err != nil {
			return PaginatedVersions{}, err
		}
		versions = append(versions, v)
	}
	if err := rows.Err(); err != nil {
		return PaginatedVersions{}, err
	}

	hasMore := len(versions) > limit
	var nextCursor *int64
	if hasMore {
		lastID := int64(versions[limit-1].ID)
		nextCursor = &lastID
		versions = versions[:limit]
	}

	return PaginatedVersions{
		Data:       versions,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

func (r *Repository) GetNodeTypeSchema(ctx context.Context, slug string) (map[string]any, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx, `SELECT schema FROM node_types WHERE slug = $1`, slug).Scan(&raw)
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

func (r *Repository) listBlocksForWorkflow(ctx context.Context, q blocksQueryer, workflowID int) ([]WorkflowBlock, error) {
	rows, err := q.Query(ctx, `
		SELECT id, workflow_id, node_type_slug, position, data
		FROM workflow_blocks
		WHERE workflow_id = $1
		ORDER BY position
	`, workflowID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	blocks := make([]WorkflowBlock, 0)
	for rows.Next() {
		var b WorkflowBlock
		var raw []byte
		if err := rows.Scan(&b.ID, &b.WorkflowID, &b.NodeTypeSlug, &b.Position, &raw); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(raw, &b.Data); err != nil {
			return nil, err
		}
		blocks = append(blocks, b)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return blocks, nil
}

func IsNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}
