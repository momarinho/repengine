package trainingmaxes

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

var _ trainingMaxRepo = (*Repository)(nil)

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) UpsertTrainingMax(ctx context.Context, in UpsertTrainingMaxInput) (TrainingMax, error) {
	row := r.pool.QueryRow(ctx, `
		INSERT INTO user_training_maxes (user_id, exercise_name, value, unit, updated_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id, exercise_name)
		DO UPDATE SET value = EXCLUDED.value, unit = EXCLUDED.unit, updated_at = NOW()
		RETURNING id, user_id, exercise_name, value, unit, updated_at
	`, in.UserID, in.ExerciseName, in.Value, in.Unit)

	var tm TrainingMax
	err := row.Scan(&tm.ID, &tm.UserID, &tm.ExerciseName, &tm.Value, &tm.Unit, &tm.UpdatedAt)
	return tm, err
}

func (r *Repository) GetTrainingMax(ctx context.Context, in GetTrainingMaxInput) (TrainingMax, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, user_id, exercise_name, value, unit, updated_at
		FROM user_training_maxes
		WHERE user_id = $1 AND exercise_name = $2
	`, in.UserID, in.ExerciseName)

	var tm TrainingMax
	err := row.Scan(&tm.ID, &tm.UserID, &tm.ExerciseName, &tm.Value, &tm.Unit, &tm.UpdatedAt)
	return tm, err
}

func (r *Repository) ListTrainingMaxes(ctx context.Context, in ListTrainingMaxesInput) ([]TrainingMax, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, exercise_name, value, unit, updated_at
		FROM user_training_maxes
		WHERE user_id = $1
		ORDER BY exercise_name ASC
	`, in.UserID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tms := make([]TrainingMax, 0)
	for rows.Next() {
		var tm TrainingMax
		if err := rows.Scan(&tm.ID, &tm.UserID, &tm.ExerciseName, &tm.Value, &tm.Unit, &tm.UpdatedAt); err != nil {
			return nil, err
		}
		tms = append(tms, tm)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return tms, nil
}

func IsNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}
