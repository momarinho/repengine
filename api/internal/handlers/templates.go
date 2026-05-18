package handlers

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v2"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	templatesvc "github.com/momarinho/rep_engine/internal/templates"
)

type Template = templatesvc.Template
type TemplateBlock = templatesvc.TemplateBlock
type CloneJob = templatesvc.CloneJob
type PaginatedTemplates = templatesvc.PaginatedTemplates

func parseTemplateID(c *fiber.Ctx) (int, error) {
	templateID := c.Params("id")
	id, err := strconv.Atoi(templateID)
	if err != nil {
		return 0, fmt.Errorf("invalid template id")
	}
	return id, nil
}

func parseCloneJobID(c *fiber.Ctx) (int, error) {
	jobID := c.Params("id")
	id, err := strconv.Atoi(jobID)
	if err != nil {
		return 0, fmt.Errorf("invalid clone job id")
	}
	return id, nil
}

func (a *App) ListTemplates(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.templates == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	in := templatesvc.ListTemplatesInput{
		UserID:   userID,
		Category: c.Query("category"),
		Cursor:   int64(c.QueryInt("cursor", 0)),
		Limit:    c.QueryInt("limit", 20),
	}

	out, err := a.templates.ListTemplates(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}
	return c.JSON(out)
}

func (a *App) GetTemplate(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.templates == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	templateID, err := parseTemplateID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	in := templatesvc.GetTemplateInput{
		UserID:     userID,
		TemplateID: templateID,
	}

	out, err := a.templates.GetTemplate(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(out)
}

func (a *App) CloneTemplate(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.templates == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	templateID, err := parseTemplateID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	key := c.Get("Idempotency-Key")
	if strings.TrimSpace(key) == "" {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("Idempotency-Key is required"))
	}

	in := templatesvc.CloneTemplateInput{
		UserID:         userID,
		TemplateID:     templateID,
		IdempotencyKey: key,
	}

	job, err := a.templates.CloneTemplate(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.Status(fiber.StatusAccepted).JSON(fiber.Map{
		"job_id": job.ID,
		"status": job.Status,
	})
}

func (a *App) GetCloneJob(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.templates == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	jobID, err := parseCloneJobID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	in := templatesvc.GetCloneJobInput{
		UserID: userID,
		JobID:  jobID,
	}

	out, err := a.templates.GetCloneJob(ctx, in)
	if err != nil {
		return apperrors.WriteAppError(c, err)
	}

	return c.JSON(out)
}
