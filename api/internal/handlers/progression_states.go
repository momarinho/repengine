package handlers

import (
	"github.com/gofiber/fiber/v2"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	progressionstatesvc "github.com/momarinho/rep_engine/internal/progression_states"
)

type ProgressionState = progressionstatesvc.ProgressionState

var progressionStateService *progressionstatesvc.Service

func SetProgressionStateService(s *progressionstatesvc.Service) {
	progressionStateService = s
}

func ListProgressionStates(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if progressionStateService == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	out, serviceErr := progressionStateService.ListProgressionStates(ctx, progressionstatesvc.ListProgressionStatesInput{
		UserID:     userID,
		WorkflowID: workflowID,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.JSON(out)
}
