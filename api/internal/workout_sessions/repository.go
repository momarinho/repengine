package workoutsessions

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

var _ workoutSessionRepo = (*Repository)(nil)

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) UserOwnsWorkflow(ctx context.Context, userID, workflowID int) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM workflows
			WHERE id = $1 AND user_id = $2
		)
	`, workflowID, userID).Scan(&exists)

	return exists, err
}

func (r *Repository) StartSession(ctx context.Context, in StartSessionInput) (WorkoutSession, error) {
	row := r.pool.QueryRow(ctx,
		`
		INSERT INTO workout_sessions (
  			workflow_id, user_id, section_id, section_title, status
  		)
  		SELECT $1, $2, $3, $4, $5
  		WHERE EXISTS (
  			SELECT 1 FROM workflows
  			WHERE id = $1 AND user_id = $2
  		)
  		RETURNING id, workflow_id, user_id,
  		          COALESCE(section_id, ''),
  		          COALESCE(section_title, ''),
  		          status, started_at, completed_at, COALESCE(notes, ''), 0
		`, in.WorkflowID, in.UserID, in.SectionID, in.SectionTitle, SessionStatusActive)

	session, err := scanWorkoutSession(row)
	if err == nil {
		return session, nil
	}

	if IsUniqueViolation(err) {
		return r.GetActiveSessionByWorkflow(ctx, in.UserID, in.WorkflowID)
	}

	return WorkoutSession{}, err
}

func (r *Repository) GetActiveSessionByWorkflow(ctx context.Context, userID, workflowID int) (WorkoutSession, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, workflow_id, user_id,
		       COALESCE(section_id, ''),
		       COALESCE(section_title, ''),
		       status, started_at, completed_at, COALESCE(notes, ''),
		       (SELECT COUNT(*) FROM workout_set_logs WHERE session_id = workout_sessions.id) AS log_count
		FROM workout_sessions
		WHERE user_id = $1
		  AND workflow_id = $2
		  AND status = $3
		ORDER BY id DESC
		LIMIT 1
	`, userID, workflowID, SessionStatusActive)

	return scanWorkoutSession(row)
}

func (r *Repository) InsertSetLog(ctx context.Context, in InsertSetLogInput) (WorkoutSetLog, error) {
	row := r.pool.QueryRow(ctx, `
		INSERT INTO workout_set_logs (
			session_id,
			workflow_block_id,
			block_client_id,
			block_position,
			node_type_slug,
			set_number,
			set_index,
			target_reps,
			prescribed_reps,
			target_load,
			prescribed_load,
			load_unit,
			target_rpe,
			prescribed_intensity,
			prescribed_rpe,
			actual_reps,
			actual_load,
			actual_rpe,
			completed,
			notes
		)
		SELECT
			$1, $2, $3, $4, $5, $6, $7, $8,
			$9, $10, $11, $12, $13, $14, $15,
			$16, $17, $18, $19, $20
		WHERE EXISTS (
			SELECT 1 FROM workout_sessions
			WHERE id = $1
			  AND user_id = $21
			  AND status = $22
		)
		ON CONFLICT (session_id, block_client_id, set_index)
		WHERE block_client_id IS NOT NULL AND block_client_id <> ''
		DO UPDATE SET
			workflow_block_id = EXCLUDED.workflow_block_id,
			node_type_slug = EXCLUDED.node_type_slug,
			prescribed_reps = EXCLUDED.prescribed_reps,
			prescribed_load = EXCLUDED.prescribed_load,
			prescribed_intensity = EXCLUDED.prescribed_intensity,
			prescribed_rpe = EXCLUDED.prescribed_rpe,
			actual_reps = EXCLUDED.actual_reps,
			actual_load = EXCLUDED.actual_load,
			actual_rpe = EXCLUDED.actual_rpe,
			completed = EXCLUDED.completed,
			notes = EXCLUDED.notes
		RETURNING id, session_id, workflow_block_id, block_client_id, node_type_slug,
		          set_index, COALESCE(prescribed_reps, ''), COALESCE(prescribed_load, ''),
		          COALESCE(prescribed_intensity, ''), COALESCE(prescribed_rpe, ''),
		          COALESCE(actual_reps, ''), COALESCE(actual_load, ''), COALESCE(actual_rpe, ''),
		          completed, COALESCE(notes, ''), created_at
	`,
		in.SessionID,
		in.WorkflowBlockID,
		in.BlockClientID,
		0,
		in.NodeTypeSlug,
		in.SetIndex,
		in.SetIndex,
		in.PrescribedReps,
		in.PrescribedReps,
		nil,
		in.PrescribedLoad,
		nil,
		in.PrescribedRPE,
		in.PrescribedIntensity,
		in.PrescribedRPE,
		in.ActualReps,
		in.ActualLoad,
		in.ActualRPE,
		in.Completed,
		in.Notes,
		in.UserID,
		SessionStatusActive,
	)

	return scanWorkoutSetLog(row)
}

func (r *Repository) CompleteSession(ctx context.Context, sessionID, userID int, notes string) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE workout_sessions
		SET
			status = $1,
			completed_at = COALESCE(completed_at, NOW()),
			notes = COALESCE(NULLIF($2, ''), notes)
		WHERE id = $3
		  AND user_id = $4
		  AND status IN ($5, $1)
	`, SessionStatusCompleted, notes, sessionID, userID, SessionStatusActive)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return nil
}

func (r *Repository) GetSession(ctx context.Context, sessionID, userID int) (WorkoutSession, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, workflow_id, user_id,
		       COALESCE(section_id, ''),
		       COALESCE(section_title, ''),
		       status, started_at, completed_at, COALESCE(notes, ''),
		       (SELECT COUNT(*) FROM workout_set_logs WHERE session_id = workout_sessions.id) AS log_count
		FROM workout_sessions
		WHERE id = $1 AND user_id = $2
	`, sessionID, userID)

	session, err := scanWorkoutSession(row)
	if err != nil {
		return WorkoutSession{}, err
	}

	logs, err := r.ListSessionLogs(ctx, session.ID)
	if err != nil {
		return WorkoutSession{}, err
	}
	session.Logs = logs

	return session, nil
}

func (r *Repository) ListSessionLogs(ctx context.Context, sessionID int) ([]WorkoutSetLog, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, session_id, workflow_block_id, COALESCE(block_client_id, ''), node_type_slug,
		       set_index, COALESCE(prescribed_reps, ''), COALESCE(prescribed_load, ''),
		       COALESCE(prescribed_intensity, ''), COALESCE(prescribed_rpe, ''),
		       COALESCE(actual_reps, ''), COALESCE(actual_load, ''), COALESCE(actual_rpe, ''),
		       completed, COALESCE(notes, ''), created_at
		FROM workout_set_logs
		WHERE session_id = $1
		ORDER BY id ASC
	`, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	logs := []WorkoutSetLog{}
	for rows.Next() {
		log, err := scanWorkoutSetLog(rows)
		if err != nil {
			return nil, err
		}
		logs = append(logs, log)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return logs, nil
}

func (r *Repository) ListSessions(
	ctx context.Context,
	userID, workflowID int,
	cursor int64,
	limit int,
) (PaginatedWorkoutSessions, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, workflow_id, user_id,
		       COALESCE(section_id, ''),
		       COALESCE(section_title, ''),
		       status, started_at, completed_at, COALESCE(notes, ''),
		       (SELECT COUNT(*) FROM workout_set_logs WHERE session_id = workout_sessions.id) AS log_count
		FROM workout_sessions
		WHERE user_id = $1
		  AND ($2 = 0 OR workflow_id = $2)
		  AND ($3 = 0 OR id < $3)
		ORDER BY id DESC
		LIMIT $4
	`, userID, workflowID, cursor, limit+1)
	if err != nil {
		return PaginatedWorkoutSessions{}, err
	}
	defer rows.Close()

	sessions := make([]WorkoutSession, 0, limit+1)
	for rows.Next() {
		session, err := scanWorkoutSession(rows)
		if err != nil {
			return PaginatedWorkoutSessions{}, err
		}
		sessions = append(sessions, session)
	}

	if err := rows.Err(); err != nil {
		return PaginatedWorkoutSessions{}, err
	}

	hasMore := len(sessions) > limit
	var nextCursor *int64
	if hasMore {
		lastID := int64(sessions[limit-1].ID)
		nextCursor = &lastID
		sessions = sessions[:limit]
	}

	return PaginatedWorkoutSessions{
		Data:       sessions,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

func scanWorkoutSession(row pgx.Row) (WorkoutSession, error) {
	var session WorkoutSession
	err := row.Scan(
		&session.ID,
		&session.WorkflowID,
		&session.UserID,
		&session.SectionID,
		&session.SectionTitle,
		&session.Status,
		&session.StartedAt,
		&session.CompletedAt,
		&session.Notes,
		&session.LogCount,
	)
	if err != nil {
		return WorkoutSession{}, err
	}

	return session, nil
}

func scanWorkoutSetLog(row pgx.Row) (WorkoutSetLog, error) {
	var log WorkoutSetLog
	err := row.Scan(
		&log.ID,
		&log.SessionID,
		&log.WorkflowBlockID,
		&log.BlockClientID,
		&log.NodeTypeSlug,
		&log.SetIndex,
		&log.PrescribedReps,
		&log.PrescribedLoad,
		&log.PrescribedIntensity,
		&log.PrescribedRPE,
		&log.ActualReps,
		&log.ActualLoad,
		&log.ActualRPE,
		&log.Completed,
		&log.Notes,
		&log.CreatedAt,
	)
	if err != nil {
		return WorkoutSetLog{}, err
	}

	return log, nil
}

func IsNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}

func IsUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
