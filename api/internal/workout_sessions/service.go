package workoutsessions

import (
	"context"
	"strconv"
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
		reqSection := strings.TrimSpace(in.SectionID)
		if reqSection != "" && activeSession.SectionID != "" && activeSession.SectionID != reqSection {
			// If the user requested a specific day/section and the active session is for a different section,
			// auto-abandon the stale conflicting active session so the user can start their new day.
			_ = s.repo.AbandonSession(ctx, activeSession.ID, in.UserID, "Auto-abandoned: user started a different workout section")
		} else {
			return activeSession, nil
		}
	}
	if !IsNotFound(err) && err != nil {
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

	prescribedReps := strings.TrimSpace(in.PrescribedReps)
	prescribedLoad := strings.TrimSpace(in.PrescribedLoad)
	actualReps := strings.TrimSpace(in.ActualReps)
	if actualReps == "" && prescribedReps != "" {
		actualReps = strings.TrimSuffix(prescribedReps, "+")
	}
	actualLoad := strings.TrimSpace(in.ActualLoad)
	if actualLoad == "" && prescribedLoad != "" {
		actualLoad = prescribedLoad
	}

	workflowBlockID := in.WorkflowBlockID
	cleanBlockClientID := strings.TrimSpace(in.BlockClientID)
	if workflowBlockID == nil && cleanBlockClientID != "" {
		if id, err := strconv.Atoi(cleanBlockClientID); err == nil && id > 0 {
			workflowBlockID = &id
		}
	}

	log, err := s.repo.InsertSetLog(ctx, InsertSetLogInput{
		UserID:              in.UserID,
		SessionID:           in.SessionID,
		WorkflowBlockID:     workflowBlockID,
		BlockClientID:       cleanBlockClientID,
		NodeTypeSlug:        strings.TrimSpace(in.NodeTypeSlug),
		SetIndex:            in.SetIndex,
		PrescribedReps:      prescribedReps,
		PrescribedLoad:      prescribedLoad,
		PrescribedIntensity: strings.TrimSpace(in.PrescribedIntensity),
		PrescribedRPE:       strings.TrimSpace(in.PrescribedRPE),
		ActualReps:          actualReps,
		ActualLoad:          actualLoad,
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
			wBlockID := log.WorkflowBlockID
			if wBlockID == nil && strings.TrimSpace(log.BlockClientID) != "" {
				if id, err := strconv.Atoi(strings.TrimSpace(log.BlockClientID)); err == nil && id > 0 {
					wBlockID = &id
				}
			}
			logs = append(logs, progressionstates.CompletedSetLog{
				WorkflowBlockID:     wBlockID,
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
		if err := s.progression.ApplySessionProgression(ctx, progressionstates.ApplySessionProgressionInput{
			UserID:     in.UserID,
			WorkflowID: session.WorkflowID,
			SessionID:  session.ID,
			Logs:       logs,
		}); err != nil {
			return WorkoutSession{}, apperrors.ErrInternal()
		}
	}

	return session, nil
}

func (s *Service) AbandonSession(ctx context.Context, in AbandonSessionInput) (WorkoutSession, error) {
	if in.SessionID <= 0 {
		return WorkoutSession{}, apperrors.ErrBadRequest("session_id is required")
	}

	if err := s.repo.AbandonSession(ctx, in.SessionID, in.UserID, strings.TrimSpace(in.Notes)); err != nil {
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

	return session, nil
}

func (s *Service) UpdateSetLog(ctx context.Context, in UpdateSetLogInput) (WorkoutSetLog, error) {
	if in.SessionID <= 0 {
		return WorkoutSetLog{}, apperrors.ErrBadRequest("session_id is required")
	}
	if in.LogID <= 0 {
		return WorkoutSetLog{}, apperrors.ErrBadRequest("log_id is required")
	}
	if strings.TrimSpace(in.NodeTypeSlug) == "" {
		return WorkoutSetLog{}, apperrors.ErrBadRequest("node_type_slug is required")
	}
	if in.SetIndex <= 0 {
		return WorkoutSetLog{}, apperrors.ErrBadRequest("set_index must be greater than zero")
	}

	log, err := s.repo.UpdateSetLog(ctx, UpdateSetLogInput{
		UserID:              in.UserID,
		SessionID:           in.SessionID,
		LogID:               in.LogID,
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
			return WorkoutSetLog{}, apperrors.ErrWorkoutSessionNotFound()
		}
		return WorkoutSetLog{}, apperrors.ErrInternal()
	}

	if s.progression != nil {
		session, err := s.repo.GetSession(ctx, in.SessionID, in.UserID)
		if err == nil && session.Status == "completed" {
			logs := make([]progressionstates.CompletedSetLog, 0, len(session.Logs))
			for _, l := range session.Logs {
				wBlockID := l.WorkflowBlockID
				if wBlockID == nil && strings.TrimSpace(l.BlockClientID) != "" {
					if id, err := strconv.Atoi(strings.TrimSpace(l.BlockClientID)); err == nil && id > 0 {
						wBlockID = &id
					}
				}
				logs = append(logs, progressionstates.CompletedSetLog{
					WorkflowBlockID:     wBlockID,
					BlockClientID:       l.BlockClientID,
					NodeTypeSlug:        l.NodeTypeSlug,
					SetIndex:            l.SetIndex,
					PrescribedReps:      l.PrescribedReps,
					PrescribedLoad:      l.PrescribedLoad,
					PrescribedIntensity: l.PrescribedIntensity,
					PrescribedRPE:       l.PrescribedRPE,
					ActualReps:          l.ActualReps,
					ActualLoad:          l.ActualLoad,
					ActualRPE:           l.ActualRPE,
					ActualRIR:           l.ActualRIR,
					Completed:           l.Completed,
					Notes:               l.Notes,
				})
			}
			_ = s.progression.ApplySessionProgression(ctx, progressionstates.ApplySessionProgressionInput{
				UserID:     in.UserID,
				WorkflowID: session.WorkflowID,
				SessionID:  session.ID,
				Logs:       logs,
			})
		}
	}

	return log, nil
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

func (s *Service) GetAnalytics(ctx context.Context, in GetAnalyticsInput) (WorkoutAnalytics, error) {
	if in.WorkflowID <= 0 {
		return WorkoutAnalytics{}, apperrors.ErrBadRequest("workflow_id is required")
	}

	ownsWorkflow, err := s.repo.UserOwnsWorkflow(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return WorkoutAnalytics{}, apperrors.ErrInternal()
	}
	if !ownsWorkflow {
		return WorkoutAnalytics{}, apperrors.ErrWorkflowNotFound()
	}

	analytics, err := s.repo.GetAnalytics(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return WorkoutAnalytics{}, apperrors.ErrInternal()
	}

	return analytics, nil
}
