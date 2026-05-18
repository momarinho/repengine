package workoutsessions

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	progressionstates "github.com/momarinho/rep_engine/internal/progression_states"
)

type fakeRepo struct {
	startSessionFunc     func(ctx context.Context, in StartSessionInput) (WorkoutSession, error)
	getActiveSessionFunc func(ctx context.Context, userID, workflowID int) (WorkoutSession, error)
	insertSetLogFunc     func(ctx context.Context, in InsertSetLogInput) (WorkoutSetLog, error)
	completeSessionFunc  func(ctx context.Context, sessionID, userID int, notes string) error
	getSessionFunc       func(ctx context.Context, sessionID, userID int) (WorkoutSession, error)
	listSessionLogsFunc  func(ctx context.Context, sessionID int) ([]WorkoutSetLog, error)
	listSessionsFunc     func(ctx context.Context, userID, workflowID int, cursor int64, limit int) (PaginatedWorkoutSessions, error)
	userOwnsWorkflowFunc func(ctx context.Context, userID, workflowID int) (bool, error)
}

type fakeProgressionApplier struct {
	applyFunc func(ctx context.Context, in progressionstates.ApplySessionProgressionInput) error
}

func (f *fakeProgressionApplier) ApplySessionProgression(ctx context.Context, in progressionstates.ApplySessionProgressionInput) error {
	if f.applyFunc == nil {
		panic("unexpected call to ApplySessionProgression")
	}
	return f.applyFunc(ctx, in)
}

func (f *fakeRepo) StartSession(ctx context.Context, in StartSessionInput) (WorkoutSession, error) {
	if f.startSessionFunc == nil {
		panic("unexpected call to StartSession")
	}
	return f.startSessionFunc(ctx, in)
}

func (f *fakeRepo) GetActiveSessionByWorkflow(ctx context.Context, userID, workflowID int) (WorkoutSession, error) {
	if f.getActiveSessionFunc == nil {
		panic("unexpected call to GetActiveSessionByWorkflow")
	}
	return f.getActiveSessionFunc(ctx, userID, workflowID)
}

func (f *fakeRepo) InsertSetLog(ctx context.Context, in InsertSetLogInput) (WorkoutSetLog, error) {
	if f.insertSetLogFunc == nil {
		panic("unexpected call to InsertSetLog")
	}
	return f.insertSetLogFunc(ctx, in)
}

func (f *fakeRepo) CompleteSession(ctx context.Context, sessionID, userID int, notes string) error {
	if f.completeSessionFunc == nil {
		panic("unexpected call to CompleteSession")
	}
	return f.completeSessionFunc(ctx, sessionID, userID, notes)
}

func (f *fakeRepo) GetSession(ctx context.Context, sessionID, userID int) (WorkoutSession, error) {
	if f.getSessionFunc == nil {
		panic("unexpected call to GetSession")
	}
	return f.getSessionFunc(ctx, sessionID, userID)
}

func (f *fakeRepo) ListSessionLogs(ctx context.Context, sessionID int) ([]WorkoutSetLog, error) {
	if f.listSessionLogsFunc == nil {
		panic("unexpected call to ListSessionLogs")
	}
	return f.listSessionLogsFunc(ctx, sessionID)
}

func (f *fakeRepo) ListSessions(ctx context.Context, userID, workflowID int, cursor int64, limit int) (PaginatedWorkoutSessions, error) {
	if f.listSessionsFunc == nil {
		panic("unexpected call to ListSessions")
	}
	return f.listSessionsFunc(ctx, userID, workflowID, cursor, limit)
}

func (f *fakeRepo) UserOwnsWorkflow(ctx context.Context, userID, workflowID int) (bool, error) {
	if f.userOwnsWorkflowFunc == nil {
		panic("unexpected call to UserOwnsWorkflow")
	}
	return f.userOwnsWorkflowFunc(ctx, userID, workflowID)
}

func requireAppError(t *testing.T, err error) *apperrors.AppError {
	t.Helper()

	if err == nil {
		t.Fatal("expected error, got nil")
	}

	var appErr *apperrors.AppError
	if !errors.As(err, &appErr) {
		t.Fatalf("expected *AppError, got %T", err)
	}

	return appErr
}

func TestServiceStartSession_Success(t *testing.T) {
	ctx := context.Background()
	var gotInput StartSessionInput

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		getActiveSessionFunc: func(ctx context.Context, userID, workflowID int) (WorkoutSession, error) {
			return WorkoutSession{}, pgx.ErrNoRows
		},
		startSessionFunc: func(ctx context.Context, in StartSessionInput) (WorkoutSession, error) {
			gotInput = in
			return WorkoutSession{ID: 15, WorkflowID: in.WorkflowID, UserID: in.UserID, Status: SessionStatusActive}, nil
		},
	}

	service := NewService(repo, nil)

	out, err := service.StartSession(ctx, StartSessionInput{
		UserID:       2,
		WorkflowID:   9,
		SectionID:    " day-1 ",
		SectionTitle: " Day 1 ",
	})
	if err != nil {
		t.Fatalf("StartSession returned error: %v", err)
	}

	if out.ID != 15 {
		t.Fatalf("expected session ID 15, got %d", out.ID)
	}
	if gotInput.SectionID != "day-1" {
		t.Fatalf("expected trimmed section ID, got %q", gotInput.SectionID)
	}
	if gotInput.SectionTitle != "Day 1" {
		t.Fatalf("expected trimmed section title, got %q", gotInput.SectionTitle)
	}
}

func TestServiceStartSession_ReusesExistingActiveSession(t *testing.T) {
	ctx := context.Background()
	startCalled := false

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		getActiveSessionFunc: func(ctx context.Context, userID, workflowID int) (WorkoutSession, error) {
			return WorkoutSession{
				ID:         21,
				WorkflowID: workflowID,
				UserID:     userID,
				Status:     SessionStatusActive,
			}, nil
		},
		startSessionFunc: func(ctx context.Context, in StartSessionInput) (WorkoutSession, error) {
			startCalled = true
			return WorkoutSession{}, nil
		},
	}

	service := NewService(repo, nil)

	out, err := service.StartSession(ctx, StartSessionInput{
		UserID:     3,
		WorkflowID: 9,
	})
	if err != nil {
		t.Fatalf("StartSession returned error: %v", err)
	}

	if out.ID != 21 {
		t.Fatalf("expected reused session ID 21, got %d", out.ID)
	}
	if startCalled {
		t.Fatal("expected repo StartSession not to be called when an active session exists")
	}
}

func TestServiceInsertSetLog_InactiveSession(t *testing.T) {
	ctx := context.Background()
	insertCalled := false

	repo := &fakeRepo{
		getSessionFunc: func(ctx context.Context, sessionID, userID int) (WorkoutSession, error) {
			return WorkoutSession{ID: sessionID, Status: SessionStatusCompleted}, nil
		},
		insertSetLogFunc: func(ctx context.Context, in InsertSetLogInput) (WorkoutSetLog, error) {
			insertCalled = true
			return WorkoutSetLog{}, nil
		},
	}

	service := NewService(repo, nil)

	_, err := service.InsertSetLog(ctx, InsertSetLogInput{
		UserID:       1,
		SessionID:    99,
		NodeTypeSlug: "exercise",
		SetIndex:     1,
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "WORKOUT_SESSION_INACTIVE" {
		t.Fatalf("expected WORKOUT_SESSION_INACTIVE, got %s", appErr.Code)
	}
	if insertCalled {
		t.Fatal("expected InsertSetLog repo call to be skipped for inactive session")
	}
}

func TestServiceCompleteSession_ReturnsUpdatedSession(t *testing.T) {
	ctx := context.Background()
	now := time.Date(2026, 5, 17, 18, 30, 0, 0, time.UTC)
	completeCalled := false

	repo := &fakeRepo{
		completeSessionFunc: func(ctx context.Context, sessionID, userID int, notes string) error {
			completeCalled = true
			if notes != "done" {
				t.Fatalf("expected notes to be forwarded, got %q", notes)
			}
			return nil
		},
		getSessionFunc: func(ctx context.Context, sessionID, userID int) (WorkoutSession, error) {
			return WorkoutSession{
				ID:          sessionID,
				UserID:      userID,
				Status:      SessionStatusCompleted,
				CompletedAt: &now,
				LogCount:    4,
			}, nil
		},
	}

	service := NewService(repo, nil)

	out, err := service.CompleteSession(ctx, CompleteSessionInput{
		UserID:    7,
		SessionID: 11,
		Notes:     "done",
	})
	if err != nil {
		t.Fatalf("CompleteSession returned error: %v", err)
	}

	if !completeCalled {
		t.Fatal("expected CompleteSession repo call")
	}
	if out.Status != SessionStatusCompleted {
		t.Fatalf("expected completed status, got %s", out.Status)
	}
	if out.LogCount != 4 {
		t.Fatalf("expected log count 4, got %d", out.LogCount)
	}
}

func TestServiceCompleteSession_ReturnsErrorWhenProgressionFails(t *testing.T) {
	ctx := context.Background()

	repo := &fakeRepo{
		completeSessionFunc: func(ctx context.Context, sessionID, userID int, notes string) error {
			return nil
		},
		getSessionFunc: func(ctx context.Context, sessionID, userID int) (WorkoutSession, error) {
			return WorkoutSession{
				ID:         sessionID,
				UserID:     userID,
				WorkflowID: 17,
				Status:     SessionStatusCompleted,
				Logs: []WorkoutSetLog{
					{
						ID:           1,
						NodeTypeSlug: "linear_progression",
						SetIndex:     1,
						Completed:    true,
					},
				},
			}, nil
		},
	}

	service := NewService(repo, &fakeProgressionApplier{
		applyFunc: func(ctx context.Context, in progressionstates.ApplySessionProgressionInput) error {
			return errors.New("boom")
		},
	})

	_, err := service.CompleteSession(ctx, CompleteSessionInput{
		UserID:    7,
		SessionID: 11,
		Notes:     "done",
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "INTERNAL_ERROR" {
		t.Fatalf("expected INTERNAL_ERROR, got %s", appErr.Code)
	}
}

func TestServiceListSessions_WorkflowNotOwned(t *testing.T) {
	ctx := context.Background()

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return false, nil
		},
	}

	service := NewService(repo, nil)

	_, err := service.ListSessions(ctx, ListSessionsInput{
		UserID:     1,
		WorkflowID: 5,
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "WORKFLOW_NOT_FOUND" {
		t.Fatalf("expected WORKFLOW_NOT_FOUND, got %s", appErr.Code)
	}
}

func TestServiceGetSession_NotFound(t *testing.T) {
	ctx := context.Background()

	repo := &fakeRepo{
		getSessionFunc: func(ctx context.Context, sessionID, userID int) (WorkoutSession, error) {
			return WorkoutSession{}, pgx.ErrNoRows
		},
	}

	service := NewService(repo, nil)

	_, err := service.GetSession(ctx, GetSessionInput{
		UserID:    1,
		SessionID: 42,
	})

	appErr := requireAppError(t, err)
	if appErr.Code != "WORKOUT_SESSION_NOT_FOUND" {
		t.Fatalf("expected WORKOUT_SESSION_NOT_FOUND, got %s", appErr.Code)
	}
}
