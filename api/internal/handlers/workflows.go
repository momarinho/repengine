package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5"
	"github.com/momarinho/rep_engine/internal/db"
)

type Workflow struct {
	ID          int             `json:"id"`
	UserID      int             `json:"user_id"`
	Name        string          `json:"name"`
	Description string          `json:"description"`
	IsPublic    bool            `json:"is_public"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`
	Blocks      []WorkflowBlock `json:"blocks,omitempty"`
}

type WorkflowBlock struct {
	ID           int            `json:"id"`
	WorkflowID   int            `json:"workflow_id"`
	NodeTypeSlug string         `json:"node_type_slug"`
	Position     int            `json:"position"`
	Data         map[string]any `json:"data"`
}

type WorkflowVersion struct {
	ID            int            `json:"id"`
	WorkflowID    int            `json:"workflow_id"`
	VersionNumber int            `json:"version_number"`
	Snapshot      map[string]any `json:"snapshot"`
	CommitMessage string         `json:"commit_message"`
	CreatedAt     time.Time      `json:"created_at"`
}

type PaginatedWorkflows struct {
	Data       []Workflow `json:"data"`
	NextCursor *int64     `json:"next_cursor"`
	HasMore    bool       `json:"has_more"`
}

type PaginatedVersions struct {
	Data       []WorkflowVersion `json:"data"`
	NextCursor *int64            `json:"next_cursor"`
	HasMore    bool              `json:"has_more"`
}

type CreateWorkflowRequest struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	IsPublic    bool            `json:"is_public"`
	Blocks      []WorkflowBlock `json:"blocks"`
}

type UpdateWorkflowRequest struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	IsPublic    *bool           `json:"is_public"`
	Blocks      []WorkflowBlock `json:"blocks"`
}

type CreateVersionRequest struct {
	CommitMessage string         `json:"commit_message"`
	Snapshot      map[string]any `json:"snapshot"`
}

func withTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, 3*time.Second)
}

func parseWorkflowID(c *fiber.Ctx) (int, error) {
	workflowID := c.Params("id")
	id, err := strconv.Atoi(workflowID)
	if err != nil {
		return 0, fmt.Errorf("invalid workflow id")
	}
	return id, nil
}

func ListWorkflows(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	userID := c.Locals("user_id").(int)
	cursor := int64(c.QueryInt("cursor", 0))
	limit := c.QueryInt("limit", 20)
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	rows, err := db.Pool.Query(ctx, `
		SELECT id, user_id, name, description, is_public, created_at, updated_at
		FROM workflows
		WHERE user_id = $1 AND ($2 = 0 OR id < $2)
		ORDER BY id DESC
		LIMIT $3
	`, userID, cursor, limit+1)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to fetch workflows"})
	}
	defer rows.Close()

	workflows := make([]Workflow, 0, limit+1)
	for rows.Next() {
		var w Workflow
		if err := rows.Scan(&w.ID, &w.UserID, &w.Name, &w.Description, &w.IsPublic, &w.CreatedAt, &w.UpdatedAt); err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to scan workflow"})
		}
		workflows = append(workflows, w)
	}

	if err := rows.Err(); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read workflows"})
	}

	hasMore := len(workflows) > limit
	var nextCursor *int64
	if hasMore {
		lastID := int64(workflows[limit-1].ID)
		nextCursor = &lastID
		workflows = workflows[:limit]
	}

	return c.JSON(PaginatedWorkflows{
		Data:       workflows,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	})
}

func CreateWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	userID := c.Locals("user_id").(int)

	var req CreateWorkflowRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}
	if req.Name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}

	for _, block := range req.Blocks {
		if err := validateBlock(block); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}
	}

	var workflow Workflow
	err := db.Pool.QueryRow(ctx, `
		INSERT INTO workflows (user_id, name, description, is_public)
		VALUES ($1, $2, $3, $4)
		RETURNING id, user_id, name, description, is_public, created_at, updated_at
	`, userID, req.Name, req.Description, req.IsPublic).Scan(
		&workflow.ID,
		&workflow.UserID,
		&workflow.Name,
		&workflow.Description,
		&workflow.IsPublic,
		&workflow.CreatedAt,
		&workflow.UpdatedAt,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create workflow"})
	}

	if len(req.Blocks) > 0 {
		workflow.Blocks = make([]WorkflowBlock, 0, len(req.Blocks))
		for i, block := range req.Blocks {
			block.WorkflowID = workflow.ID
			block.Position = i
			blockID, err := insertBlock(ctx, block)
			if err != nil {
				return c.Status(500).JSON(fiber.Map{"error": "failed to create workflow block"})
			}
			block.ID = blockID
			workflow.Blocks = append(workflow.Blocks, block)
		}
	}

	return c.Status(201).JSON(workflow)
}

func GetWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	var w Workflow
	err = db.Pool.QueryRow(ctx, `
		SELECT id, user_id, name, description, is_public, created_at, updated_at
		FROM workflows
		WHERE id = $1 AND (user_id = $2 OR is_public = true)
	`, workflowID, userID).Scan(
		&w.ID,
		&w.UserID,
		&w.Name,
		&w.Description,
		&w.IsPublic,
		&w.CreatedAt,
		&w.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return c.Status(404).JSON(fiber.Map{"error": "workflow not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "failed to fetch workflow"})
	}

	rows, err := db.Pool.Query(ctx, `
		SELECT id, workflow_id, node_type_slug, position, data
		FROM workflow_blocks
		WHERE workflow_id = $1
		ORDER BY position
	`, workflowID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to fetch blocks"})
	}
	defer rows.Close()

	w.Blocks = make([]WorkflowBlock, 0)
	for rows.Next() {
		var block WorkflowBlock
		var dataJSON []byte
		if err := rows.Scan(&block.ID, &block.WorkflowID, &block.NodeTypeSlug, &block.Position, &dataJSON); err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to scan block"})
		}
		if err := json.Unmarshal(dataJSON, &block.Data); err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to parse block data"})
		}
		w.Blocks = append(w.Blocks, block)
	}
	if err := rows.Err(); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read blocks"})
	}

	return c.JSON(w)
}

func UpdateWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	var req UpdateWorkflowRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}

	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to start transaction"})
	}
	defer tx.Rollback(ctx)

	var currentUserID int
	err = tx.QueryRow(ctx, `SELECT user_id FROM workflows WHERE id = $1`, workflowID).Scan(&currentUserID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return c.Status(404).JSON(fiber.Map{"error": "workflow not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "failed to fetch workflow"})
	}
	if currentUserID != userID {
		return c.Status(403).JSON(fiber.Map{"error": "not authorized"})
	}

	_, err = tx.Exec(ctx, `
		UPDATE workflows
		SET name = $1, description = $2, is_public = COALESCE($3, is_public), updated_at = NOW()
		WHERE id = $4
	`, req.Name, req.Description, req.IsPublic, workflowID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to update workflow"})
	}

	_, err = tx.Exec(ctx, `DELETE FROM workflow_blocks WHERE workflow_id = $1`, workflowID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to delete blocks"})
	}

	for i, block := range req.Blocks {
		block.WorkflowID = workflowID
		block.Position = i
		if err := validateBlock(block); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}
		dataJSON, err := json.Marshal(block.Data)
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "invalid block data"})
		}
		_, err = tx.Exec(ctx, `
			INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
			VALUES ($1, $2, $3, $4)
		`, block.WorkflowID, block.NodeTypeSlug, block.Position, dataJSON)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to insert block"})
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to commit transaction"})
	}

	return GetWorkflow(c)
}

func DeleteWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	result, err := db.Pool.Exec(ctx, `DELETE FROM workflows WHERE id = $1 AND user_id = $2`, workflowID, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to delete workflow"})
	}
	if result.RowsAffected() == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "workflow not found"})
	}

	return c.SendStatus(204)
}

func CreateVersion(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	var wfUserID int
	err = db.Pool.QueryRow(ctx, `SELECT user_id FROM workflows WHERE id = $1`, workflowID).Scan(&wfUserID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return c.Status(404).JSON(fiber.Map{"error": "workflow not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "failed to fetch workflow"})
	}
	if wfUserID != userID {
		return c.Status(403).JSON(fiber.Map{"error": "not authorized"})
	}

	var req CreateVersionRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}

	snapshotJSON, err := json.Marshal(req.Snapshot)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid snapshot"})
	}

	var version WorkflowVersion
	err = db.Pool.QueryRow(ctx, `
		INSERT INTO workflow_versions (workflow_id, version_number, snapshot, commit_message)
		SELECT $1, COALESCE(MAX(version_number), 0) + 1, $2, $3
		FROM workflow_versions
		WHERE workflow_id = $1
		RETURNING id, workflow_id, version_number, snapshot, commit_message, created_at
	`, workflowID, snapshotJSON, req.CommitMessage).Scan(
		&version.ID,
		&version.WorkflowID,
		&version.VersionNumber,
		&snapshotJSON,
		&version.CommitMessage,
		&version.CreatedAt,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create version"})
	}
	if err := json.Unmarshal(snapshotJSON, &version.Snapshot); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse version snapshot"})
	}

	return c.Status(201).JSON(version)
}

func ListVersions(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	cursor := int64(c.QueryInt("cursor", 0))
	limit := c.QueryInt("limit", 20)
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	var wfUserID int
	err = db.Pool.QueryRow(ctx, `SELECT user_id FROM workflows WHERE id = $1`, workflowID).Scan(&wfUserID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return c.Status(404).JSON(fiber.Map{"error": "workflow not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "failed to fetch workflow"})
	}
	if wfUserID != userID {
		return c.Status(403).JSON(fiber.Map{"error": "not authorized"})
	}

	rows, err := db.Pool.Query(ctx, `
		SELECT id, workflow_id, version_number, snapshot, commit_message, created_at
		FROM workflow_versions
		WHERE workflow_id = $1 AND ($2 = 0 OR id < $2)
		ORDER BY version_number DESC
		LIMIT $3
	`, workflowID, cursor, limit+1)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to fetch versions"})
	}
	defer rows.Close()

	versions := make([]WorkflowVersion, 0, limit+1)
	for rows.Next() {
		var v WorkflowVersion
		var snapshotJSON []byte
		if err := rows.Scan(&v.ID, &v.WorkflowID, &v.VersionNumber, &snapshotJSON, &v.CommitMessage, &v.CreatedAt); err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to scan version"})
		}
		if err := json.Unmarshal(snapshotJSON, &v.Snapshot); err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to parse version snapshot"})
		}
		versions = append(versions, v)
	}
	if err := rows.Err(); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read versions"})
	}

	hasMore := len(versions) > limit
	var nextCursor *int64
	if hasMore {
		lastID := int64(versions[limit-1].ID)
		nextCursor = &lastID
		versions = versions[:limit]
	}

	return c.JSON(PaginatedVersions{
		Data:       versions,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	})
}

func validateBlock(block WorkflowBlock) error {
	if block.NodeTypeSlug == "" {
		return errors.New("node_type_slug is required")
	}
	nodeType, ok := nodeTypesCache[block.NodeTypeSlug]
	if !ok {
		return fmt.Errorf("unknown node_type_slug: %s", block.NodeTypeSlug)
	}

	if len(nodeType.Schema) == 0 {
		return nil
	}

	if block.Data == nil {
		return errors.New("data is required for this node_type_slug")
	}

	for key, schemaValue := range nodeType.Schema {
		dataValue, exists := block.Data[key]
		if !exists {
			return fmt.Errorf("missing data field %q", key)
		}
		if !isSameJSONType(schemaValue, dataValue) {
			return fmt.Errorf("invalid type for data field %q: expected %s, got %s",
				key, jsonTypeName(schemaValue), jsonTypeName(dataValue))
		}
	}

	for key := range block.Data {
		if _, exists := nodeType.Schema[key]; !exists {
			return fmt.Errorf("unknown data field %q for node_type_slug %q", key, block.NodeTypeSlug)
		}
	}

	return nil
}

func isSameJSONType(expected, actual any) bool {
	expectedType := jsonTypeName(expected)
	actualType := jsonTypeName(actual)

	if expectedType == "number" && actualType == "number" {
		return true
	}

	return expectedType == actualType
}

func jsonTypeName(value any) string {
	switch value.(type) {
	case nil:
		return "null"
	case bool:
		return "boolean"
	case string:
		return "string"
	case float32, float64, int, int8, int16, int32, int64, uint, uint8,
		uint16, uint32, uint64:
		return "number"
	case []any:
		return "array"
	case map[string]any:
		return "object"
	default:
		return fmt.Sprintf("%T", value)
	}
}

func insertBlock(ctx context.Context, block WorkflowBlock) (int, error) {
	dataJSON, err := json.Marshal(block.Data)
	if err != nil {
		return 0, err
	}

	var blockID int
	err = db.Pool.QueryRow(ctx, `
		INSERT INTO workflow_blocks (workflow_id, node_type_slug, position, data)
		VALUES ($1, $2, $3, $4)
		RETURNING id
	`, block.WorkflowID, block.NodeTypeSlug, block.Position, dataJSON).Scan(&blockID)
	if err != nil {
		return 0, err
	}

	return blockID, nil
}
