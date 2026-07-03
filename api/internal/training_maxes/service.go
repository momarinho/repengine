package trainingmaxes

import (
	"context"
	"strings"

	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

type Service struct {
	repo trainingMaxRepo
}

func NewService(repo trainingMaxRepo) *Service {
	return &Service{repo: repo}
}

func (s *Service) UpsertTrainingMax(ctx context.Context, in UpsertTrainingMaxInput) (TrainingMax, error) {
	in.ExerciseName = strings.TrimSpace(in.ExerciseName)
	if in.ExerciseName == "" {
		return TrainingMax{}, apperrors.ErrBadRequest("exercise_name is required")
	}
	if in.Value <= 0 {
		return TrainingMax{}, apperrors.ErrBadRequest("training max value must be greater than zero")
	}
	in.Unit = strings.TrimSpace(strings.ToLower(in.Unit))
	if in.Unit != "kg" && in.Unit != "lb" && in.Unit != "lbs" {
		in.Unit = "kg"
	}

	tm, err := s.repo.UpsertTrainingMax(ctx, in)
	if err != nil {
		return TrainingMax{}, apperrors.ErrInternal()
	}

	return tm, nil
}

func (s *Service) GetTrainingMax(ctx context.Context, in GetTrainingMaxInput) (TrainingMax, error) {
	in.ExerciseName = strings.TrimSpace(in.ExerciseName)
	if in.ExerciseName == "" {
		return TrainingMax{}, apperrors.ErrBadRequest("exercise_name is required")
	}

	tm, err := s.repo.GetTrainingMax(ctx, in)
	if err != nil {
		if IsNotFound(err) {
			return TrainingMax{}, apperrors.New(404, "TRAINING_MAX_NOT_FOUND", "Training max not found for this exercise")
		}
		return TrainingMax{}, apperrors.ErrInternal()
	}

	return tm, nil
}

func (s *Service) ListTrainingMaxes(ctx context.Context, in ListTrainingMaxesInput) ([]TrainingMax, error) {
	tms, err := s.repo.ListTrainingMaxes(ctx, in)
	if err != nil {
		return nil, apperrors.ErrInternal()
	}

	return tms, nil
}
