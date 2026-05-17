package workoutsessions

import "context"

type workoutSessionRepo interface {
	StartSession(ctx context.Context, in StartSessionInput) (WorkoutSession, error)
	GetActiveSessionByWorkflow(ctx context.Context, userID, workflowID int) (WorkoutSession, error)
	InsertSetLog(ctx context.Context, in InsertSetLogInput) (WorkoutSetLog, error)
	CompleteSession(ctx context.Context, sessionID, userID int, notes string) error
	GetSession(ctx context.Context, sessionID, userID int) (WorkoutSession, error)
	ListSessionLogs(ctx context.Context, sessionID int) ([]WorkoutSetLog, error)
	ListSessions(ctx context.Context, userID, workflowID int, cursor int64, limit int) (PaginatedWorkoutSessions, error)
	UserOwnsWorkflow(ctx context.Context, userID, workflowID int) (bool, error)
}
