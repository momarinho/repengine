package handlers

import (
	"fmt"
	"strconv"

	"github.com/gofiber/fiber/v2"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	workoutsessionsvc "github.com/momarinho/rep_engine/internal/workout_sessions"
)

type WorkoutSession = workoutsessionsvc.WorkoutSession
type WorkoutSetLog = workoutsessionsvc.WorkoutSetLog
type PaginatedWorkoutSessions = workoutsessionsvc.PaginatedWorkoutSessions

type StartWorkoutSessionRequest struct {
	SectionID    string `json:"section_id"`
	SectionTitle string `json:"section_title"`
}

type CreateWorkoutSetLogRequest struct {
	WorkflowBlockID     *int   `json:"workflow_block_id"`
	BlockClientID       string `json:"block_client_id"`
	NodeTypeSlug        string `json:"node_type_slug"`
	SetIndex            int    `json:"set_index"`
	PrescribedReps      string `json:"prescribed_reps"`
	PrescribedLoad      string `json:"prescribed_load"`
	PrescribedIntensity string `json:"prescribed_intensity"`
	PrescribedRPE       string `json:"prescribed_rpe"`
	ActualReps          string `json:"actual_reps"`
	ActualLoad          string `json:"actual_load"`
	ActualRPE           string `json:"actual_rpe"`
	Completed           bool   `json:"completed"`
	Notes               string `json:"notes"`
}

type CompleteWorkoutSessionRequest struct {
	Notes string `json:"notes"`
}

var workoutSessionService *workoutsessionsvc.Service

func SetWorkoutSessionService(s *workoutsessionsvc.Service) {
	workoutSessionService = s
}

func parseWorkoutSessionID(c *fiber.Ctx) (int, error) {
	sessionID := c.Params("id")
	id, err := strconv.Atoi(sessionID)
	if err != nil {
		return 0, fmt.Errorf("invalid workout session id")
	}
	return id, nil
}

func ListWorkoutSessions(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if workoutSessionService == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	out, serviceErr := workoutSessionService.ListSessions(ctx, workoutsessionsvc.ListSessionsInput{
		UserID:     userID,
		WorkflowID: workflowID,
		Cursor:     int64(c.QueryInt("cursor", 0)),
		Limit:      c.QueryInt("limit", 20),
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.JSON(out)
}

func StartWorkoutSession(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if workoutSessionService == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	workflowID, err := parseWorkflowID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	var req StartWorkoutSessionRequest
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request body"))
	}

	out, serviceErr := workoutSessionService.StartSession(ctx, workoutsessionsvc.StartSessionInput{
		UserID:       userID,
		WorkflowID:   workflowID,
		SectionID:    req.SectionID,
		SectionTitle: req.SectionTitle,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.Status(fiber.StatusCreated).JSON(out)
}

func GetWorkoutSession(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if workoutSessionService == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	sessionID, err := parseWorkoutSessionID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	out, serviceErr := workoutSessionService.GetSession(ctx, workoutsessionsvc.GetSessionInput{
		UserID:    userID,
		SessionID: sessionID,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.JSON(out)
}

func CreateWorkoutSetLog(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if workoutSessionService == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	sessionID, err := parseWorkoutSessionID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	var req CreateWorkoutSetLogRequest
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request body"))
	}

	out, serviceErr := workoutSessionService.InsertSetLog(ctx, workoutsessionsvc.InsertSetLogInput{
		UserID:              userID,
		SessionID:           sessionID,
		WorkflowBlockID:     req.WorkflowBlockID,
		BlockClientID:       req.BlockClientID,
		NodeTypeSlug:        req.NodeTypeSlug,
		SetIndex:            req.SetIndex,
		PrescribedReps:      req.PrescribedReps,
		PrescribedLoad:      req.PrescribedLoad,
		PrescribedIntensity: req.PrescribedIntensity,
		PrescribedRPE:       req.PrescribedRPE,
		ActualReps:          req.ActualReps,
		ActualLoad:          req.ActualLoad,
		ActualRPE:           req.ActualRPE,
		Completed:           req.Completed,
		Notes:               req.Notes,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.Status(fiber.StatusCreated).JSON(out)
}

func CompleteWorkoutSession(c *fiber.Ctx) error {
	ctx, cancel := withTimeout(c.UserContext())
	defer cancel()

	if workoutSessionService == nil {
		return apperrors.WriteAppError(c, apperrors.ErrInternal())
	}

	userID := c.Locals("user_id").(int)
	sessionID, err := parseWorkoutSessionID(c)
	if err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest(err.Error()))
	}

	var req CompleteWorkoutSessionRequest
	if err := c.BodyParser(&req); err != nil {
		return apperrors.WriteAppError(c, apperrors.ErrBadRequest("invalid request body"))
	}

	out, serviceErr := workoutSessionService.CompleteSession(ctx, workoutsessionsvc.CompleteSessionInput{
		UserID:    userID,
		SessionID: sessionID,
		Notes:     req.Notes,
	})
	if serviceErr != nil {
		return apperrors.WriteAppError(c, serviceErr)
	}

	return c.JSON(out)
}
