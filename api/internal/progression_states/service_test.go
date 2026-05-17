package progressionstates

import (
	"context"
	"testing"
)

type fakeRepo struct {
	userOwnsWorkflowFunc       func(ctx context.Context, userID, workflowID int) (bool, error)
	listWorkflowBlocksFunc     func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error)
	listProgressionStatesFunc  func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error)
	upsertProgressionStateFunc func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error)
}

func (f *fakeRepo) UserOwnsWorkflow(ctx context.Context, userID, workflowID int) (bool, error) {
	return f.userOwnsWorkflowFunc(ctx, userID, workflowID)
}

func (f *fakeRepo) ListWorkflowBlocks(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
	return f.listWorkflowBlocksFunc(ctx, workflowID)
}

func (f *fakeRepo) ListProgressionStates(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
	return f.listProgressionStatesFunc(ctx, userID, workflowID)
}

func (f *fakeRepo) UpsertProgressionState(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
	return f.upsertProgressionStateFunc(ctx, in)
}

func TestApplySessionProgression_LinearIncrease(t *testing.T) {
	ctx := context.Background()
	var gotState UpsertProgressionStateInput

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           11,
					NodeTypeSlug: "linear_progression",
					Position:     1,
					Data: map[string]any{
						"exercise_name":    "Squat",
						"sets":             3,
						"reps":             "5",
						"start_load":       100.0,
						"load_unit":        "kg",
						"increment":        2.5,
						"progression_rule": "add_each_session",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return nil, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			gotState = in
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)

	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     2,
		WorkflowID: 9,
		SessionID:  21,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 1, ActualReps: "5", ActualRPE: "8", ActualLoad: "100 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 2, ActualReps: "5", ActualRPE: "8", ActualLoad: "100 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 3, ActualReps: "5", ActualRPE: "8.5", ActualLoad: "100 kg"},
		},
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}

	if gotState.StateType != StateTypeLinear {
		t.Fatalf("expected linear state, got %q", gotState.StateType)
	}
	if gotState.Outcome != OutcomeIncrease {
		t.Fatalf("expected increase outcome, got %q", gotState.Outcome)
	}
	if gotState.SuggestedLoad != "102.5 kg" {
		t.Fatalf("expected suggested load 102.5 kg, got %q", gotState.SuggestedLoad)
	}
}

func TestApplySessionProgression_WaveReduce(t *testing.T) {
	ctx := context.Background()
	var gotState UpsertProgressionStateInput

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           14,
					NodeTypeSlug: "wave",
					Position:     1,
					Data: map[string]any{
						"exercise_name":    "Bench Press",
						"active_week":      2.0,
						"week_1_reps":      "5/5/5+",
						"week_1_intensity": "65/70/75",
						"week_2_reps":      "3/3/3+",
						"week_2_intensity": "70/75/80",
						"week_3_reps":      "5/3/1+",
						"week_3_intensity": "75/80/85",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return nil, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			gotState = in
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)

	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     2,
		WorkflowID: 9,
		SessionID:  22,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 1, PrescribedRPE: "8", ActualRPE: "8.5"},
			{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 2, PrescribedRPE: "8", ActualRPE: "9"},
			{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 3, PrescribedRPE: "9", ActualRPE: "10"},
		},
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}

	if gotState.StateType != StateTypeWave {
		t.Fatalf("expected wave state, got %q", gotState.StateType)
	}
	if gotState.Outcome != OutcomeReduce {
		t.Fatalf("expected reduce outcome, got %q", gotState.Outcome)
	}
	if gotState.SuggestedWeek != 2 {
		t.Fatalf("expected to repeat week 2, got %d", gotState.SuggestedWeek)
	}
	if gotState.SuggestedIntensityOffset != "-2.5" {
		t.Fatalf("expected suggested intensity offset -2.5, got %q", gotState.SuggestedIntensityOffset)
	}
}

func TestApplySessionProgression_CreatesSkillStateWithoutSkillLogs(t *testing.T) {
	ctx := context.Background()
	states := make([]UpsertProgressionStateInput, 0, 2)

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           2628,
					NodeTypeSlug: "section",
					Position:     0,
					Data:         map[string]any{"title": "Day 1"},
				},
				{
					ID:           2629,
					NodeTypeSlug: "linear_progression",
					Position:     1,
					Data: map[string]any{
						"exercise_name":    "Squat",
						"sets":             3,
						"reps":             "5",
						"start_load":       100.0,
						"load_unit":        "kg",
						"increment":        2.5,
						"progression_rule": "add_each_session",
					},
				},
				{
					ID:           2631,
					NodeTypeSlug: "exercise",
					Position:     2,
					Data: map[string]any{
						"exercise_name": "Crow Pose Practice",
						"sets":          3,
						"reps":          "20-30s",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return nil, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			states = append(states, in)
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)
	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     39,
		WorkflowID: 55,
		SessionID:  17,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(2629), Completed: true, SetIndex: 1, ActualReps: "5", ActualRPE: "8", ActualRIR: "2", ActualLoad: "100 kg"},
		},
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}
	if len(states) != 2 {
		t.Fatalf("expected 2 states (linear + skill), got %d", len(states))
	}

	var foundSkill bool
	for _, state := range states {
		if state.StateType != StateTypeSkill {
			continue
		}
		foundSkill = true
		if state.Outcome != OutcomeMaintain {
			t.Fatalf("expected skill maintain outcome without logs, got %q", state.Outcome)
		}
		if state.LastLogCount != 0 {
			t.Fatalf("expected skill log count 0, got %d", state.LastLogCount)
		}
	}
	if !foundSkill {
		t.Fatal("expected skill progression state to be created")
	}
}

func intPtr(value int) *int {
	return &value
}
