package handlers

import (
	"github.com/gofiber/fiber/v2"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	progressionstatesvc "github.com/momarinho/rep_engine/internal/progression_states"
)

type ProgressionState = progressionstatesvc.ProgressionState

func (a *App) ListProgressionStates(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.progression == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	out, serviceErr := a.progression.ListProgressionStates(ctx, progressionstatesvc.ListProgressionStatesInput{
		UserID:     userID,
		WorkflowID: workflowID,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.JSON(out)
}
