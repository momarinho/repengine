package trainingmaxes

import (
	"context"
	"errors"
	"testing"
)

type mockRepo struct {
	tms map[string]TrainingMax
}

func (m *mockRepo) UpsertTrainingMax(ctx context.Context, in UpsertTrainingMaxInput) (TrainingMax, error) {
	tm := TrainingMax{
		ID:           1,
		UserID:       in.UserID,
		ExerciseName: in.ExerciseName,
		Value:        in.Value,
		Unit:         in.Unit,
	}
	m.tms[in.ExerciseName] = tm
	return tm, nil
}

func (m *mockRepo) GetTrainingMax(ctx context.Context, in GetTrainingMaxInput) (TrainingMax, error) {
	tm, ok := m.tms[in.ExerciseName]
	if !ok {
		return TrainingMax{}, errors.New("no rows")
	}
	return tm, nil
}

func (m *mockRepo) ListTrainingMaxes(ctx context.Context, in ListTrainingMaxesInput) ([]TrainingMax, error) {
	var list []TrainingMax
	for _, tm := range m.tms {
		if tm.UserID == in.UserID {
			list = append(list, tm)
		}
	}
	return list, nil
}

func TestUpsertTrainingMax(t *testing.T) {
	repo := &mockRepo{tms: make(map[string]TrainingMax)}
	svc := NewService(repo)

	// Valid upsert
	tm, err := svc.UpsertTrainingMax(context.Background(), UpsertTrainingMaxInput{
		UserID:       1,
		ExerciseName: "Squat",
		Value:        100,
		Unit:         "kg",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tm.ExerciseName != "Squat" || tm.Value != 100 || tm.Unit != "kg" {
		t.Errorf("unexpected training max returned: %+v", tm)
	}

	// Invalid value
	_, err = svc.UpsertTrainingMax(context.Background(), UpsertTrainingMaxInput{
		UserID:       1,
		ExerciseName: "Bench Press",
		Value:        0,
		Unit:         "kg",
	})
	if err == nil {
		t.Error("expected error for zero value")
	}

	// Empty exercise name
	_, err = svc.UpsertTrainingMax(context.Background(), UpsertTrainingMaxInput{
		UserID:       1,
		ExerciseName: "  ",
		Value:        50,
		Unit:         "kg",
	})
	if err == nil {
		t.Error("expected error for empty exercise name")
	}
}

func TestGetTrainingMax(t *testing.T) {
	repo := &mockRepo{tms: make(map[string]TrainingMax)}
	svc := NewService(repo)

	_, _ = repo.UpsertTrainingMax(context.Background(), UpsertTrainingMaxInput{
		UserID:       1,
		ExerciseName: "Deadlift",
		Value:        150,
		Unit:         "kg",
	})

	// Valid get
	tm, err := svc.GetTrainingMax(context.Background(), GetTrainingMaxInput{
		UserID:       1,
		ExerciseName: "Deadlift",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tm.ExerciseName != "Deadlift" || tm.Value != 150 {
		t.Errorf("unexpected training max returned: %+v", tm)
	}

	// Non-existent get
	_, err = svc.GetTrainingMax(context.Background(), GetTrainingMaxInput{
		UserID:       1,
		ExerciseName: "Squat",
	})
	if err == nil {
		t.Error("expected error for non-existent training max")
	}
}
