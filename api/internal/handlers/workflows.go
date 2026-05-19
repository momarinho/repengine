package handlers

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	workflowsvc "github.com/momarinho/rep_engine/internal/workflows"
)

type Workflow = workflowsvc.Workflow
type WorkflowBlock = workflowsvc.WorkflowBlock
type WorkflowVersion = workflowsvc.WorkflowVersion
type PaginatedWorkflows = workflowsvc.PaginatedWorkflows
type PaginatedVersions = workflowsvc.PaginatedVersions

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
	UpdatedAt   string          `json:"updated_at"`
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

func parseVersionID(c *fiber.Ctx) (int, error) {
	versionID := c.Params("versionId")
	id, err := strconv.Atoi(versionID)
	if err != nil {
		return 0, fmt.Errorf("invalid version id")
	}
	return id, nil
}

func (a *App) ListWorkflows(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	in := workflowsvc.ListWorkflowsInput{
		UserID: userID,
		Cursor: int64(c.QueryInt("cursor", 0)),
		Limit:  c.QueryInt("limit", 20),
	}

	out, err := a.workflows.ListWorkflows(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(out)
}

func (a *App) CreateWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)

	var req CreateWorkflowRequest
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request body"))
	}

	in := workflowsvc.CreateWorkflowInput{
		UserID:      userID,
		Name:        req.Name,
		Description: req.Description,
		IsPublic:    req.IsPublic,
		Blocks:      req.Blocks,
	}

	out, err := a.workflows.CreateWorkflow(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.Status(201).JSON(out)
}

func (a *App) GetWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	in := workflowsvc.GetWorkflowInput{
		UserID:     userID,
		WorkflowID: workflowID,
	}

	out, err := a.workflows.GetWorkflow(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(out)
}

func (a *App) UpdateWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	var req UpdateWorkflowRequest
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request body"))
	}

	updatedAt, err := time.Parse(time.RFC3339Nano, req.UpdatedAt)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("updated_at must be RFC3339"))
	}

	in := workflowsvc.UpdateWorkflowInput{
		WorkflowID:  workflowID,
		UserID:      userID,
		Name:        req.Name,
		Description: req.Description,
		IsPublic:    req.IsPublic,
		UpdatedAt:   updatedAt,
		Blocks:      req.Blocks,
	}

	out, err := a.workflows.UpdateWorkflow(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(out)
}

func (a *App) DeleteWorkflow(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	in := workflowsvc.DeleteWorkflowInput{
		UserID:     userID,
		WorkflowID: workflowID,
	}

	if err := a.workflows.DeleteWorkflow(ctx, in); err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.SendStatus(204)
}

func (a *App) CreateVersion(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	var req CreateVersionRequest
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request body"))
	}

	in := workflowsvc.CreateVersionInput{
		UserID:        userID,
		WorkflowID:    workflowID,
		CommitMessage: req.CommitMessage,
		Snapshot:      req.Snapshot,
	}

	out, err := a.workflows.CreateVersion(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.Status(201).JSON(out)
}

func (a *App) ListVersions(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	in := workflowsvc.ListVersionsInput{
		UserID:     userID,
		WorkflowID: workflowID,
		Cursor:     int64(c.QueryInt("cursor", 0)),
		Limit:      c.QueryInt("limit", 20),
	}

	out, err := a.workflows.ListVersions(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(out)
}

func (a *App) RestoreVersion(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.workflows == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}
	versionID, err := parseVersionID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	out, err := a.workflows.RestoreVersion(ctx, workflowsvc.RestoreVersionInput{
		UserID:     userID,
		WorkflowID: workflowID,
		VersionID:  versionID,
	})
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(out)
}
