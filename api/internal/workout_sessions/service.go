package workoutsessions

import (
	"context"
	"strings"

	apperrors "github.com/momarinho/rep_engine/internal/errors"
	progressionstates "github.com/momarinho/rep_engine/internal/progression_states"
)

type Service struct {
	repo        workoutSessionRepo
	progression progressionApplier
}

func NewService(repo workoutSessionRepo, progression progressionApplier) *Service {
	return &Service{repo: repo, progression: progression}
}

func (s *Service) StartSession(ctx context.Context, in StartSessionInput) (WorkoutSession, error) {
	if in.WorkflowID <= 0 {
		return WorkoutSession{}, apperrors.ErrBadRequest("workflow_id is required")
	}

	ownsWorkflow, err := s.repo.UserOwnsWorkflow(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return WorkoutSession{}, apperrors.ErrInternal()
	}
	if !ownsWorkflow {
		return WorkoutSession{}, apperrors.ErrWorkflowNotFound()
	}

	activeSession, err := s.repo.GetActiveSessionByWorkflow(ctx, in.UserID, in.WorkflowID)
	if err == nil {
		return activeSession, nil
	}
	if !IsNotFound(err) {
		return WorkoutSession{}, apperrors.ErrInternal()
	}

	session, err := s.repo.StartSession(ctx, StartSessionInput{
		UserID:       in.UserID,
		WorkflowID:   in.WorkflowID,
		SectionID:    strings.TrimSpace(in.SectionID),
		SectionTitle: strings.TrimSpace(in.SectionTitle),
	})
	if err != nil {
		if IsNotFound(err) {
			return WorkoutSession{}, apperrors.ErrWorkflowNotFound()
		}
		return WorkoutSession{}, apperrors.ErrInternal()
	}

	return session, nil
}

func (s *Service) InsertSetLog(ctx context.Context, in InsertSetLogInput) (WorkoutSetLog, error) {
	if in.SessionID <= 0 {
		return WorkoutSetLog{}, apperrors.ErrBadRequest("session_id is required")
	}
	if strings.TrimSpace(in.NodeTypeSlug) == "" {
		return WorkoutSetLog{}, apperrors.ErrBadRequest("node_type_slug is required")
	}
	if in.SetIndex <= 0 {
		return WorkoutSetLog{}, apperrors.ErrBadRequest("set_index must be greater than zero")
	}

	session, err := s.repo.GetSession(ctx, in.SessionID, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return WorkoutSetLog{}, apperrors.ErrWorkoutSessionNotFound()
		}
		return WorkoutSetLog{}, apperrors.ErrInternal()
	}
	if session.Status != SessionStatusActive {
		return WorkoutSetLog{}, apperrors.ErrWorkoutSessionInactive()
	}

	log, err := s.repo.InsertSetLog(ctx, InsertSetLogInput{
		UserID:              in.UserID,
		SessionID:           in.SessionID,
		WorkflowBlockID:     in.WorkflowBlockID,
		BlockClientID:       strings.TrimSpace(in.BlockClientID),
		NodeTypeSlug:        strings.TrimSpace(in.NodeTypeSlug),
		SetIndex:            in.SetIndex,
		PrescribedReps:      strings.TrimSpace(in.PrescribedReps),
		PrescribedLoad:      strings.TrimSpace(in.PrescribedLoad),
		PrescribedIntensity: strings.TrimSpace(in.PrescribedIntensity),
		PrescribedRPE:       strings.TrimSpace(in.PrescribedRPE),
		ActualReps:          strings.TrimSpace(in.ActualReps),
		ActualLoad:          strings.TrimSpace(in.ActualLoad),
		ActualRPE:           strings.TrimSpace(in.ActualRPE),
		ActualRIR:           strings.TrimSpace(in.ActualRIR),
		Completed:           in.Completed,
		Notes:               strings.TrimSpace(in.Notes),
	})
	if err != nil {
		if IsNotFound(err) {
			return WorkoutSetLog{}, apperrors.ErrWorkoutSessionInactive()
		}
		return WorkoutSetLog{}, apperrors.ErrInternal()
	}

	return log, nil
}

func (s *Service) CompleteSession(ctx context.Context, in CompleteSessionInput) (WorkoutSession, error) {
	if in.SessionID <= 0 {
		return WorkoutSession{}, apperrors.ErrBadRequest("session_id is required")
	}

	if err := s.repo.CompleteSession(ctx, in.SessionID, in.UserID, strings.TrimSpace(in.Notes)); err != nil {
		if IsNotFound(err) {
			return WorkoutSession{}, apperrors.ErrWorkoutSessionNotFound()
		}
		return WorkoutSession{}, apperrors.ErrInternal()
	}

	session, err := s.repo.GetSession(ctx, in.SessionID, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return WorkoutSession{}, apperrors.ErrWorkoutSessionNotFound()
		}
		return WorkoutSession{}, apperrors.ErrInternal()
	}

	if s.progression != nil {
		logs := make([]progressionstates.CompletedSetLog, 0, len(session.Logs))
		for _, log := range session.Logs {
			logs = append(logs, progressionstates.CompletedSetLog{
				WorkflowBlockID:     log.WorkflowBlockID,
				BlockClientID:       log.BlockClientID,
				NodeTypeSlug:        log.NodeTypeSlug,
				SetIndex:            log.SetIndex,
				PrescribedReps:      log.PrescribedReps,
				PrescribedLoad:      log.PrescribedLoad,
				PrescribedIntensity: log.PrescribedIntensity,
				PrescribedRPE:       log.PrescribedRPE,
				ActualReps:          log.ActualReps,
				ActualLoad:          log.ActualLoad,
				ActualRPE:           log.ActualRPE,
				ActualRIR:           log.ActualRIR,
				Completed:           log.Completed,
				Notes:               log.Notes,
			})
		}
		_ = s.progression.ApplySessionProgression(ctx, progressionstates.ApplySessionProgressionInput{
			UserID:     in.UserID,
			WorkflowID: session.WorkflowID,
			SessionID:  session.ID,
			Logs:       logs,
		})
	}

	return session, nil
}

func (s *Service) GetSession(ctx context.Context, in GetSessionInput) (WorkoutSession, error) {
	if in.SessionID <= 0 {
		return WorkoutSession{}, apperrors.ErrBadRequest("session_id is required")
	}

	session, err := s.repo.GetSession(ctx, in.SessionID, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return WorkoutSession{}, apperrors.ErrWorkoutSessionNotFound()
		}
		return WorkoutSession{}, apperrors.ErrInternal()
	}

	return session, nil
}

func (s *Service) ListSessions(ctx context.Context, in ListSessionsInput) (PaginatedWorkoutSessions, error) {
	if in.WorkflowID <= 0 {
		return PaginatedWorkoutSessions{}, apperrors.ErrBadRequest("workflow_id is required")
	}

	ownsWorkflow, err := s.repo.UserOwnsWorkflow(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return PaginatedWorkoutSessions{}, apperrors.ErrInternal()
	}
	if !ownsWorkflow {
		return PaginatedWorkoutSessions{}, apperrors.ErrWorkflowNotFound()
	}

	limit := in.Limit
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	out, err := s.repo.ListSessions(ctx, in.UserID, in.WorkflowID, in.Cursor, limit)
	if err != nil {
		return PaginatedWorkoutSessions{}, apperrors.ErrInternal()
	}

	return out, nil
}
