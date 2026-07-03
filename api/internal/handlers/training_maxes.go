package handlers

import (
	"github.com/gofiber/fiber/v2"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	trainingmaxesvc "github.com/momarinho/rep_engine/internal/training_maxes"
)

type UpsertTrainingMaxRequest struct {
	ExerciseName string  `json:"exercise_name"`
	Value        float64 `json:"value"`
	Unit         string  `json:"unit"`
}

func (a *App) UpsertTrainingMax(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.trainingMaxes == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)

	var req UpsertTrainingMaxRequest
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request body"))
	}

	out, serviceErr := a.trainingMaxes.UpsertTrainingMax(ctx, trainingmaxesvc.UpsertTrainingMaxInput{
		UserID:       userID,
		ExerciseName: req.ExerciseName,
		Value:        req.Value,
		Unit:         req.Unit,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.JSON(out)
}

func (a *App) ListTrainingMaxes(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if a.trainingMaxes == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)

	out, serviceErr := a.trainingMaxes.ListTrainingMaxes(ctx, trainingmaxesvc.ListTrainingMaxesInput{
		UserID: userID,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.JSON(out)
}
