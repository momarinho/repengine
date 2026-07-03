package trainingmaxes

import "context"

type trainingMaxRepo interface {
	UpsertTrainingMax(ctx context.Context, in UpsertTrainingMaxInput) (TrainingMax, error)
	GetTrainingMax(ctx context.Context, in GetTrainingMaxInput) (TrainingMax, error)
	ListTrainingMaxes(ctx context.Context, in ListTrainingMaxesInput) ([]TrainingMax, error)
}
