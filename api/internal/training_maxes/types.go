package trainingmaxes

import "time"

type TrainingMax struct {
	ID           int       `json:"id"`
	UserID       int       `json:"user_id"`
	ExerciseName string    `json:"exercise_name"`
	Value        float64   `json:"value"`
	Unit         string    `json:"unit"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type UpsertTrainingMaxInput struct {
	UserID       int     `json:"user_id"`
	ExerciseName string  `json:"exercise_name"`
	Value        float64 `json:"value"`
	Unit         string  `json:"unit"`
}

type GetTrainingMaxInput struct {
	UserID       int    `json:"user_id"`
	ExerciseName string `json:"exercise_name"`
}

type ListTrainingMaxesInput struct {
	UserID int `json:"user_id"`
}
