package workoutsessions

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/momarinho/rep_engine/internal/fitness"
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
	actualLoadValue := fitness.OptionalFirstNumberString(in.ActualLoad)
	actualRPEValue := fitness.OptionalFirstNumberString(in.ActualRPE)
	actualRIRValue := fitness.OptionalFirstNumberString(in.ActualRIR)

	row := r.pool.QueryRow(ctx, `
		INSERT INTO workout_set_logs (
			session_id,
			workflow_block_id,
			block_client_id,
			node_type_slug,
			set_index,
			prescribed_reps,
			prescribed_load,
			prescribed_intensity,
			prescribed_rpe,
			actual_reps,
			actual_load,
			actual_rpe,
			actual_rir,
			actual_load_value,
			actual_rpe_value,
			actual_rir_value,
			completed,
			notes
		)
		SELECT
			$1, $2, $3, $4, $5,
			$6, $7, $8, $9,
			$10, $11, $12, $13,
			$14, $15, $16,
			$17, $18
		WHERE EXISTS (
			SELECT 1 FROM workout_sessions
			WHERE id = $1
			  AND user_id = $19
			  AND status = $20
		)
		ON CONFLICT (session_id, block_client_id, set_index)
		WHERE block_client_id IS NOT NULL AND block_client_id <> ''
		DO UPDATE SET
			workflow_block_id    = EXCLUDED.workflow_block_id,
			node_type_slug       = EXCLUDED.node_type_slug,
			prescribed_reps      = EXCLUDED.prescribed_reps,
			prescribed_load      = EXCLUDED.prescribed_load,
			prescribed_intensity = EXCLUDED.prescribed_intensity,
			prescribed_rpe       = EXCLUDED.prescribed_rpe,
			actual_reps          = EXCLUDED.actual_reps,
			actual_load          = EXCLUDED.actual_load,
			actual_rpe           = EXCLUDED.actual_rpe,
			actual_rir           = EXCLUDED.actual_rir,
			actual_load_value    = EXCLUDED.actual_load_value,
			actual_rpe_value     = EXCLUDED.actual_rpe_value,
			actual_rir_value     = EXCLUDED.actual_rir_value,
			completed            = EXCLUDED.completed,
			notes                = EXCLUDED.notes
		RETURNING id, session_id, workflow_block_id, block_client_id, node_type_slug,
		          set_index, COALESCE(prescribed_reps, ''), COALESCE(prescribed_load, ''),
		          COALESCE(prescribed_intensity, ''), COALESCE(prescribed_rpe, ''),
		          COALESCE(actual_reps, ''), COALESCE(actual_load, ''), COALESCE(actual_rpe, ''),
		          COALESCE(actual_rir, ''),
		          completed, COALESCE(notes, ''), created_at
	`,
		in.SessionID,           // $1
		in.WorkflowBlockID,     // $2
		in.BlockClientID,       // $3
		in.NodeTypeSlug,        // $4
		in.SetIndex,            // $5
		in.PrescribedReps,      // $6
		in.PrescribedLoad,      // $7
		in.PrescribedIntensity, // $8
		in.PrescribedRPE,       // $9
		in.ActualReps,          // $10
		in.ActualLoad,          // $11
		in.ActualRPE,           // $12
		in.ActualRIR,           // $13
		actualLoadValue,        // $14
		actualRPEValue,         // $15
		actualRIRValue,         // $16
		in.Completed,           // $17
		in.Notes,               // $18
		in.UserID,              // $19
		SessionStatusActive,    // $20
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

func (r *Repository) AbandonSession(ctx context.Context, sessionID, userID int, notes string) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE workout_sessions
		SET
			status = $1,
			completed_at = COALESCE(completed_at, NOW()),
			notes = COALESCE(NULLIF($2, ''), notes)
		WHERE id = $3
		  AND user_id = $4
		  AND status = $5
	`, SessionStatusAbandoned, notes, sessionID, userID, SessionStatusActive)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return nil
}

func (r *Repository) UpdateSetLog(ctx context.Context, in UpdateSetLogInput) (WorkoutSetLog, error) {
	actualLoadValue := fitness.OptionalFirstNumberString(in.ActualLoad)
	actualRPEValue := fitness.OptionalFirstNumberString(in.ActualRPE)
	actualRIRValue := fitness.OptionalFirstNumberString(in.ActualRIR)

	row := r.pool.QueryRow(ctx, `
		UPDATE workout_set_logs AS logs
		SET
			workflow_block_id = $1,
			block_client_id = $2,
			node_type_slug = $3,
			set_index = $4,
			prescribed_reps = $5,
			prescribed_load = $6,
			prescribed_intensity = $7,
			prescribed_rpe = $8,
			actual_reps = $9,
			actual_load = $10,
			actual_rpe = $11,
			actual_rir = $12,
			actual_load_value = $13,
			actual_rpe_value = $14,
			actual_rir_value = $15,
			completed = $16,
			notes = $17
		FROM workout_sessions AS sessions
		WHERE logs.id = $18
		  AND logs.session_id = $19
		  AND sessions.id = logs.session_id
		  AND sessions.user_id = $20
		RETURNING logs.id, logs.session_id, logs.workflow_block_id, COALESCE(logs.block_client_id, ''),
		          logs.node_type_slug, logs.set_index, COALESCE(logs.prescribed_reps, ''),
		          COALESCE(logs.prescribed_load, ''), COALESCE(logs.prescribed_intensity, ''),
		          COALESCE(logs.prescribed_rpe, ''), COALESCE(logs.actual_reps, ''),
		          COALESCE(logs.actual_load, ''), COALESCE(logs.actual_rpe, ''),
		          COALESCE(logs.actual_rir, ''), logs.completed, COALESCE(logs.notes, ''), logs.created_at
	`,
		in.WorkflowBlockID,
		in.BlockClientID,
		in.NodeTypeSlug,
		in.SetIndex,
		in.PrescribedReps,
		in.PrescribedLoad,
		in.PrescribedIntensity,
		in.PrescribedRPE,
		in.ActualReps,
		in.ActualLoad,
		in.ActualRPE,
		in.ActualRIR,
		actualLoadValue,
		actualRPEValue,
		actualRIRValue,
		in.Completed,
		in.Notes,
		in.LogID,
		in.SessionID,
		in.UserID,
	)

	return scanWorkoutSetLog(row)
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
		       COALESCE(actual_rir, ''),
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

func (r *Repository) GetAnalytics(ctx context.Context, userID, workflowID int) (WorkoutAnalytics, error) {
	var analytics WorkoutAnalytics
	var avgRPE pgtype.Float8
	var avgRIR pgtype.Float8
	var lastCompletedAt pgtype.Timestamptz

	err := r.pool.QueryRow(ctx, `
		SELECT
			$2 AS workflow_id,
			COUNT(*) FILTER (WHERE sessions.status = 'completed')::INTEGER AS completed_sessions,
			COUNT(*) FILTER (WHERE sessions.status = 'abandoned')::INTEGER AS abandoned_sessions,
			COUNT(logs.id) FILTER (WHERE logs.completed)::INTEGER AS total_logged_sets,
			COALESCE(SUM(
				COALESCE(logs.actual_load_value, 0) *
				COALESCE(
					CASE
						WHEN logs.actual_reps ~ '-?[0-9]+(\.[0-9]+)?'
							THEN substring(logs.actual_reps FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(10,2)
						ELSE 0
					END,
					0
				)
			), 0)::DOUBLE PRECISION AS total_volume,
			AVG(logs.actual_rpe_value)::DOUBLE PRECISION AS average_rpe,
			AVG(logs.actual_rir_value)::DOUBLE PRECISION AS average_rir,
			MAX(sessions.completed_at) FILTER (WHERE sessions.status = 'completed') AS last_completed_at
		FROM workout_sessions AS sessions
		LEFT JOIN workout_set_logs AS logs
		  ON logs.session_id = sessions.id
		WHERE sessions.user_id = $1
		  AND sessions.workflow_id = $2
	`, userID, workflowID).Scan(
		&analytics.WorkflowID,
		&analytics.CompletedSessions,
		&analytics.AbandonedSessions,
		&analytics.TotalLoggedSets,
		&analytics.TotalVolume,
		&avgRPE,
		&avgRIR,
		&lastCompletedAt,
	)
	if err != nil {
		return WorkoutAnalytics{}, err
	}

	if avgRPE.Valid {
		analytics.AverageRPE = &avgRPE.Float64
	}
	if avgRIR.Valid {
		analytics.AverageRIR = &avgRIR.Float64
	}
	if lastCompletedAt.Valid {
		analytics.LastCompletedAt = &lastCompletedAt.Time
	}

	return analytics, nil
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
		&log.ActualRIR,
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
