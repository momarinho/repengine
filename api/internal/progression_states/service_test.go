package progressionstates

import (
	"context"
	"testing"
)

type fakeRepo struct {
	userOwnsWorkflowFunc       func(ctx context.Context, userID, workflowID int) (bool, error)
	listWorkflowBlocksFunc     func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error)
	listProgressionStatesFunc  func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error)
	listLatestLogsByBlockFunc  func(ctx context.Context, userID, workflowID int) ([]HistoricalCompletedSetLog, error)
	listCompletedLogsByBlockFn func(ctx context.Context, userID, workflowID int) ([]HistoricalCompletedSetLog, error)
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

func (f *fakeRepo) ListLatestCompletedLogsByBlock(ctx context.Context, userID, workflowID int) ([]HistoricalCompletedSetLog, error) {
	if f.listLatestLogsByBlockFunc == nil {
		return nil, nil
	}
	return f.listLatestLogsByBlockFunc(ctx, userID, workflowID)
}

func (f *fakeRepo) ListCompletedLogsByBlock(ctx context.Context, userID, workflowID int) ([]HistoricalCompletedSetLog, error) {
	if f.listCompletedLogsByBlockFn == nil {
		return nil, nil
	}
	return f.listCompletedLogsByBlockFn(ctx, userID, workflowID)
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

func TestApplySessionProgression_WaveInfersCurrentWeekFromLogsWhenStateIsMissing(t *testing.T) {
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
						"active_week":      1.0,
						"week_1_reps":      "5/5/5+",
						"week_1_intensity": "65/70/75",
						"week_1_rpe":       "7/7/8",
						"week_2_reps":      "3/3/3+",
						"week_2_intensity": "70/75/80",
						"week_2_rpe":       "7/8/8.5",
						"week_3_reps":      "5/3/1+",
						"week_3_intensity": "75/80/85",
						"week_3_rpe":       "8/8.5/9",
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
		SessionID:  23,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 1, PrescribedReps: "3", PrescribedIntensity: "70", PrescribedRPE: "7", ActualRPE: "7.5"},
			{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 2, PrescribedReps: "3", PrescribedIntensity: "75", PrescribedRPE: "8", ActualRPE: "8"},
			{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 3, PrescribedReps: "3+", PrescribedIntensity: "80", PrescribedRPE: "8.5", ActualRPE: "8.5"},
		},
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}

	if gotState.CurrentWeek != 2 {
		t.Fatalf("expected inferred current week 2, got %d", gotState.CurrentWeek)
	}
	if gotState.SuggestedWeek != 3 {
		t.Fatalf("expected suggested week 3, got %d", gotState.SuggestedWeek)
	}
	if gotState.Outcome != OutcomeIncrease {
		t.Fatalf("expected increase outcome, got %q", gotState.Outcome)
	}
}

func TestListProgressionStates_RebuildsMissingWaveStateFromHistory(t *testing.T) {
	ctx := context.Background()

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
						"exercise_name":    "Upper Push",
						"active_week":      1.0,
						"week_1_reps":      "5/5/5+",
						"week_1_intensity": "65/70/75",
						"week_1_rpe":       "7/7/8",
						"week_2_reps":      "3/3/3+",
						"week_2_intensity": "70/75/80",
						"week_2_rpe":       "7/8/8.5",
						"week_3_reps":      "5/3/1+",
						"week_3_intensity": "75/80/85",
						"week_3_rpe":       "8/8.5/9",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return nil, nil
		},
		listLatestLogsByBlockFunc: func(ctx context.Context, userID, workflowID int) ([]HistoricalCompletedSetLog, error) {
			return []HistoricalCompletedSetLog{
				{SessionID: 31, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 1, PrescribedReps: "3", PrescribedIntensity: "70", PrescribedRPE: "7", ActualRPE: "7.5"}},
				{SessionID: 31, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 2, PrescribedReps: "3", PrescribedIntensity: "75", PrescribedRPE: "8", ActualRPE: "8"}},
				{SessionID: 31, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 3, PrescribedReps: "3+", PrescribedIntensity: "80", PrescribedRPE: "8.5", ActualRPE: "8.5"}},
			}, nil
		},
		listCompletedLogsByBlockFn: func(ctx context.Context, userID, workflowID int) ([]HistoricalCompletedSetLog, error) {
			return []HistoricalCompletedSetLog{
				{SessionID: 31, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 1, PrescribedReps: "3", PrescribedIntensity: "70", PrescribedRPE: "7", ActualReps: "3", ActualLoad: "30 kg", ActualRPE: "7.5"}},
				{SessionID: 31, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 2, PrescribedReps: "3", PrescribedIntensity: "75", PrescribedRPE: "8", ActualReps: "3", ActualLoad: "32.5 kg", ActualRPE: "8"}},
				{SessionID: 31, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 3, PrescribedReps: "3+", PrescribedIntensity: "80", PrescribedRPE: "8.5", ActualReps: "5", ActualLoad: "35 kg", ActualRPE: "8.5"}},
				{SessionID: 27, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 1, PrescribedReps: "5", PrescribedIntensity: "65", PrescribedRPE: "7", ActualReps: "5", ActualLoad: "25 kg", ActualRPE: "7"}},
				{SessionID: 27, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 2, PrescribedReps: "5", PrescribedIntensity: "70", PrescribedRPE: "7", ActualReps: "5", ActualLoad: "27.5 kg", ActualRPE: "7.5"}},
				{SessionID: 27, CompletedSetLog: CompletedSetLog{WorkflowBlockID: intPtr(14), Completed: true, SetIndex: 3, PrescribedReps: "5+", PrescribedIntensity: "75", PrescribedRPE: "8", ActualReps: "8", ActualLoad: "30 kg", ActualRPE: "8"}},
			}, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)
	states, err := service.ListProgressionStates(ctx, ListProgressionStatesInput{
		UserID:     2,
		WorkflowID: 9,
	})
	if err != nil {
		t.Fatalf("ListProgressionStates returned error: %v", err)
	}

	if len(states) != 1 {
		t.Fatalf("expected 1 synthesized state, got %d", len(states))
	}
	if states[0].CurrentWeek != 2 {
		t.Fatalf("expected synthesized current week 2, got %d", states[0].CurrentWeek)
	}
	if states[0].SuggestedWeek != 3 {
		t.Fatalf("expected synthesized suggested week 3, got %d", states[0].SuggestedWeek)
	}
	if states[0].WorkflowBlockID != 14 {
		t.Fatalf("expected workflow block id 14, got %d", states[0].WorkflowBlockID)
	}
	weekHistory, ok := states[0].Metadata["week_history"].([]map[string]any)
	if !ok {
		raw, ok := states[0].Metadata["week_history"].([]any)
		if !ok || len(raw) != 2 {
			t.Fatalf("expected 2 week history entries, got %#v", states[0].Metadata["week_history"])
		}
		return
	}
	if len(weekHistory) != 2 {
		t.Fatalf("expected 2 week history entries, got %d", len(weekHistory))
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

func TestApplySessionProgression_LinearFailSequence(t *testing.T) {
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
						"fail_sequence":    "5x3 -> 6x2 -> 10x1",
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

	// User fails: only logs 2 reps in the last set (needs 3 reps per set at step index 0: 5x3)
	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     2,
		WorkflowID: 9,
		SessionID:  21,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 1, ActualReps: "3", ActualRPE: "9", ActualLoad: "100 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 2, ActualReps: "3", ActualRPE: "9", ActualLoad: "100 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 3, ActualReps: "3", ActualRPE: "9", ActualLoad: "100 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 4, ActualReps: "3", ActualRPE: "9", ActualLoad: "100 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 5, ActualReps: "2", ActualRPE: "10", ActualLoad: "100 kg"}, // failed set
		},
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}

	if gotState.Outcome != OutcomeReduce {
		t.Fatalf("expected reduce outcome due to failure, got %q", gotState.Outcome)
	}
	if gotState.SuggestedLoad != "100 kg" {
		t.Fatalf("expected suggested load 100 kg (no decrease for transition), got %q", gotState.SuggestedLoad)
	}
	if index := gotState.Metadata["current_sequence_index"].(int); index != 1 {
		t.Fatalf("expected current_sequence_index to transition to 1, got %d", index)
	}
}

func TestApplySessionProgression_LinearFailSequenceReset(t *testing.T) {
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
						"fail_sequence":    "5x3 -> 6x2 -> 10x1",
						"reset_percent":    0.80, // reset to 80%
						"start_load":       100.0,
						"load_unit":        "kg",
						"increment":        2.5,
						"progression_rule": "add_each_session",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			// Simulate being at index 2 (10x1) currently
			return []ProgressionState{
				{
					WorkflowBlockID: 11,
					BlockKey:        "::linear_progression::squat::1",
					StateType:       StateTypeLinear,
					CurrentLoad:     "100 kg",
					SuggestedLoad:   "100 kg",
					Metadata: map[string]any{
						"current_sequence_index": 2, // 10x1
					},
				},
			}, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			gotState = in
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)

	// User fails at 10x1 (only completes 9 sets)
	var logs []CompletedSetLog
	for i := 1; i <= 9; i++ {
		logs = append(logs, CompletedSetLog{
			WorkflowBlockID: intPtr(11),
			Completed:       true,
			SetIndex:        i,
			ActualReps:      "1",
			ActualRPE:       "9.5",
			ActualLoad:      "100 kg",
		})
	}

	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     2,
		WorkflowID: 9,
		SessionID:  21,
		Logs:       logs,
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}

	if gotState.Outcome != OutcomeReduce {
		t.Fatalf("expected reduce outcome, got %q", gotState.Outcome)
	}
	// 100 * 0.8 = 80
	if gotState.SuggestedLoad != "80 kg" {
		t.Fatalf("expected suggested load 80 kg (reset to 80%%), got %q", gotState.SuggestedLoad)
	}
	if index := gotState.Metadata["current_sequence_index"].(int); index != 0 {
		t.Fatalf("expected current_sequence_index to reset to 0, got %d", index)
	}
}

func TestApplySessionProgression_LinearRounding(t *testing.T) {
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
						"exercise_name":      "Squat",
						"rounding_precision": 2.5, // round to nearest 2.5 kg/lb
						"start_load":         100.0,
						"load_unit":          "kg",
						"increment":          2.4, // increment is 2.4, but rounding to 2.5 means suggestions should be 102.5
						"progression_rule":   "add_each_session",
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
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 1, ActualReps: "5", ActualRPE: "8", ActualLoad: "100.0 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 2, ActualReps: "5", ActualRPE: "8", ActualLoad: "100.0 kg"},
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 3, ActualReps: "5", ActualRPE: "8", ActualLoad: "100.0 kg"},
		},
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}

	if gotState.SuggestedLoad != "102.5 kg" {
		t.Fatalf("expected suggested load 102.5 kg (rounded from 102.4), got %q", gotState.SuggestedLoad)
	}
}

func TestApplySessionProgression_LinearDeload(t *testing.T) {
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
						"deload_weeks":     4,    // trigger deload every 4 sessions
						"deload_percent":   0.90, // deload to 90%
						"start_load":       100.0,
						"load_unit":        "kg",
						"increment":        2.5,
						"progression_rule": "add_each_session",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			// Simulate being at session_count = 3 (so this next increase is the 4th, triggering deload!)
			return []ProgressionState{
				{
					WorkflowBlockID: 11,
					BlockKey:        "::linear_progression::squat::1",
					StateType:       StateTypeLinear,
					CurrentLoad:     "100 kg",
					SuggestedLoad:   "100 kg",
					Metadata: map[string]any{
						"session_count": 3,
					},
				},
			}, nil
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
			{WorkflowBlockID: intPtr(11), Completed: true, SetIndex: 3, ActualReps: "5", ActualRPE: "8", ActualLoad: "100 kg"},
		},
	})
	if err != nil {
		t.Fatalf("ApplySessionProgression returned error: %v", err)
	}

	if gotState.Outcome != OutcomeIncrease {
		t.Fatalf("expected increase outcome, got %q", gotState.Outcome)
	}
	// 100 * 0.9 = 90
	if gotState.SuggestedLoad != "90 kg" {
		t.Fatalf("expected suggested load 90 kg (90%% deload), got %q", gotState.SuggestedLoad)
	}
	if count := gotState.Metadata["session_count"].(int); count != 4 {
		t.Fatalf("expected session_count to increment to 4, got %d", count)
	}
}

func intPtr(value int) *int {
	return &value
}

func TestListProgressionStates_SynchronizesWithUpdatedBlockConfig(t *testing.T) {
	ctx := context.Background()

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
						"sets":             5,
						"reps":             "3",
						"fail_sequence":    "5x3 -> 6x2",
						"start_load":       100.0,
						"load_unit":        "kg",
						"increment":        2.5,
						"progression_rule": "add_each_session",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return []ProgressionState{
				{
					ID:              1,
					UserID:          2,
					WorkflowID:      9,
					WorkflowBlockID: 11,
					BlockKey:        "::linear_progression::squat::1",
					NodeTypeSlug:    "linear_progression",
					StateType:       StateTypeLinear,
					Metadata: map[string]any{
						"fail_sequence":          "3x5 -> 5x3 -> 6x2",
						"current_sequence_index": 0,
						"sets_planned":           3,
						"reps_planned":           "5",
						"target_reps_lower":      5.0,
						"increment":              2.5,
						"load_unit":              "kg",
						"progression_rule":       "add_each_session",
					},
				},
			}, nil
		},
	}

	service := NewService(repo)

	states, err := service.ListProgressionStates(ctx, ListProgressionStatesInput{
		UserID:     2,
		WorkflowID: 9,
	})
	if err != nil {
		t.Fatalf("ListProgressionStates returned error: %v", err)
	}

	if len(states) != 1 {
		t.Fatalf("expected 1 progression state, got %d", len(states))
	}

	state := states[0]
	if seq := asString(state.Metadata["fail_sequence"]); seq != "5x3 -> 6x2" {
		t.Fatalf("expected fail_sequence to sync to \"5x3 -> 6x2\", got %q", seq)
	}
	if sets := intOrDefault(state.Metadata["sets_planned"], 0); sets != 5 {
		t.Fatalf("expected sets_planned to sync to 5, got %d", sets)
	}
	if reps := asString(state.Metadata["reps_planned"]); reps != "3" {
		t.Fatalf("expected reps_planned to sync to \"3\", got %q", reps)
	}
}

func TestListProgressionStates_SynchronizesDirectSetsReps(t *testing.T) {
	ctx := context.Background()

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
						"sets":             5,
						"reps":             "3",
						"fail_sequence":    "",
						"start_load":       100.0,
						"load_unit":        "kg",
						"increment":        2.5,
						"progression_rule": "add_each_session",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return []ProgressionState{
				{
					ID:              1,
					UserID:          2,
					WorkflowID:      9,
					WorkflowBlockID: 11,
					BlockKey:        "::linear_progression::squat::1",
					NodeTypeSlug:    "linear_progression",
					StateType:       StateTypeLinear,
					Metadata: map[string]any{
						"fail_sequence":     "",
						"sets_planned":      3,
						"reps_planned":      "5",
						"target_reps_lower": 5.0,
						"increment":         2.5,
						"load_unit":         "kg",
						"progression_rule":  "add_each_session",
					},
				},
			}, nil
		},
	}

	service := NewService(repo)

	states, err := service.ListProgressionStates(ctx, ListProgressionStatesInput{
		UserID:     2,
		WorkflowID: 9,
	})
	if err != nil {
		t.Fatalf("ListProgressionStates returned error: %v", err)
	}

	if len(states) != 1 {
		t.Fatalf("expected 1 progression state, got %d", len(states))
	}

	state := states[0]
	if sets := intOrDefault(state.Metadata["sets_planned"], 0); sets != 5 {
		t.Fatalf("expected sets_planned to sync to 5, got %d", sets)
	}
	if reps := asString(state.Metadata["reps_planned"]); reps != "3" {
		t.Fatalf("expected reps_planned to sync to \"3\", got %q", reps)
	}
}

func TestApplySession_ExerciseWithLinearProgressionObject(t *testing.T) {
	ctx := context.Background()
	var gotState UpsertProgressionStateInput

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           15,
					NodeTypeSlug: "exercise",
					Position:     0,
					Data: map[string]any{
						"exercise_name": "Bench Press",
						"sets":          3,
						"reps":          "5",
						"load_value":    80.0,
						"load_unit":     "kg",
						"progression": map[string]any{
							"type":      "linear",
							"increment": 2.5,
							"rule":      "add_each_session",
						},
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
		UserID:     1,
		WorkflowID: 1,
		SessionID:  10,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(15), Completed: true, SetIndex: 1, PrescribedReps: "5", PrescribedLoad: "80 kg", ActualReps: "5", ActualLoad: "80 kg", ActualRPE: "8"},
			{WorkflowBlockID: intPtr(15), Completed: true, SetIndex: 2, PrescribedReps: "5", PrescribedLoad: "80 kg", ActualReps: "5", ActualLoad: "80 kg", ActualRPE: "8"},
			{WorkflowBlockID: intPtr(15), Completed: true, SetIndex: 3, PrescribedReps: "5", PrescribedLoad: "80 kg", ActualReps: "5", ActualLoad: "80 kg", ActualRPE: "8.5"},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if gotState.StateType != StateTypeLinear {
		t.Fatalf("expected linear state, got %q", gotState.StateType)
	}
	if gotState.Outcome != OutcomeIncrease {
		t.Fatalf("expected OutcomeIncrease, got %s", gotState.Outcome)
	}
	if gotState.SuggestedLoad != "82.5 kg" {
		t.Fatalf("expected SuggestedLoad 82.5 kg, got %s", gotState.SuggestedLoad)
	}
}

func TestApplySessionProgression_DeloadPreservesBaseline(t *testing.T) {
	ctx := context.Background()

	var gotState UpsertProgressionStateInput
	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           15,
					Position:     0,
					NodeTypeSlug: "linear_progression",
					Data: map[string]any{
						"exercise_name": "Back Squat",
						"sets":          3,
						"reps":          "5",
						"increment":     2.5,
						"load_unit":     "kg",
					},
				},
				{
					ID:           16,
					Position:     1,
					NodeTypeSlug: "deload",
					Data: map[string]any{
						"title":     "Recovery Protocol",
						"is_active": true,
						"strategy":  "volume",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return []ProgressionState{
				{
					WorkflowBlockID: 15,
					BlockKey:        "::linear_progression::back-squat::1",
					CurrentLoad:     "100 kg",
					SuggestedLoad:   "102.5 kg",
					Outcome:         OutcomeIncrease,
					Metadata: map[string]any{
						"session_count": 4,
					},
				},
			}, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			gotState = in
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)

	// In deload, user lifts fewer reps / lighter load or takes it easy
	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     1,
		WorkflowID: 1,
		SessionID:  20,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(15), Completed: true, SetIndex: 1, PrescribedReps: "5", PrescribedLoad: "80 kg", ActualReps: "4", ActualLoad: "80 kg", ActualRPE: "6"},
			{WorkflowBlockID: intPtr(15), Completed: true, SetIndex: 2, PrescribedReps: "5", PrescribedLoad: "80 kg", ActualReps: "4", ActualLoad: "80 kg", ActualRPE: "6"},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if gotState.Outcome != OutcomeMaintain {
		t.Fatalf("expected OutcomeMaintain during deload, got %s", gotState.Outcome)
	}
	if gotState.SuggestedLoad != "102.5 kg" {
		t.Fatalf("expected baseline 102.5 kg preserved, got %s", gotState.SuggestedLoad)
	}
	if isDeload, ok := gotState.Metadata["is_deload"].(bool); !ok || !isDeload {
		t.Fatalf("expected is_deload true in metadata, got %v", gotState.Metadata["is_deload"])
	}
}

func TestApplySessionProgression_DoubleProgressionAdvanceReps(t *testing.T) {
	ctx := context.Background()
	var gotState UpsertProgressionStateInput

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           10,
					Position:     0,
					NodeTypeSlug: "exercise",
					Data: map[string]any{
						"exercise_name": "Bodyweight Pull-Up",
						"sets":          3,
						"reps":          "5-8",
						"load_value":    0.0,
						"load_unit":     "kg",
						"progression": map[string]any{
							"type":      "double",
							"min_reps":  5,
							"max_reps":  8,
							"increment": 2.5,
						},
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return []ProgressionState{}, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			gotState = in
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)

	// User logged 5 reps across all 3 sets at 0 kg
	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     1,
		WorkflowID: 1,
		SessionID:  5,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(10), Completed: true, SetIndex: 1, ActualReps: "5", ActualLoad: "0 kg"},
			{WorkflowBlockID: intPtr(10), Completed: true, SetIndex: 2, ActualReps: "5", ActualLoad: "0 kg"},
			{WorkflowBlockID: intPtr(10), Completed: true, SetIndex: 3, ActualReps: "5", ActualLoad: "0 kg"},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if gotState.Outcome != OutcomeMaintain {
		t.Fatalf("expected OutcomeMaintain for double progression mid-range, got %s", gotState.Outcome)
	}
	if gotState.SuggestedLoad != "0 kg" {
		t.Fatalf("expected 0 kg maintained, got %s", gotState.SuggestedLoad)
	}
	// Next rep target should advance from 5 to 6
	if targetReps, ok := gotState.Metadata["target_reps"].(int); !ok || targetReps != 6 {
		t.Fatalf("expected next target_reps 6, got %v", gotState.Metadata["target_reps"])
	}
}

func TestApplySessionProgression_SupersetDoubleProgression(t *testing.T) {
	ctx := context.Background()
	var gotState UpsertProgressionStateInput

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           20,
					Position:     0,
					NodeTypeSlug: "superset",
					Data: map[string]any{
						"exercise_a_name":    "Pull-Up (Pronated Grip)",
						"exercise_b_name":    "Barbell Squat",
						"sets":               3,
						"reps_a":             "5-8",
						"reps_b":             "5-8",
						"progression_type_a": "double",
						"progression_type_b": "double",
						"min_reps_a":         5,
						"max_reps_a":         8,
						"min_reps_b":         5,
						"max_reps_b":         8,
						"start_load_a":       0.0,
						"start_load_b":       35.0,
						"increment_a":        2.5,
						"increment_b":        2.5,
						"load_unit_a":        "kg",
						"load_unit_b":        "kg",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return []ProgressionState{}, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			gotState = in
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)

	// User logs 5 reps for Pull-Up (0 kg) and 5 reps for Barbell Squat (35 kg) across 3 sets
	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     1,
		WorkflowID: 1,
		SessionID:  8,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(20), Completed: true, SetIndex: 1, ActualReps: "5/5", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(20), Completed: true, SetIndex: 2, ActualReps: "5/5", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(20), Completed: true, SetIndex: 3, ActualReps: "5/5", ActualLoad: "0/35 kg"},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if gotState.NodeTypeSlug != "superset" {
		t.Fatalf("expected node_type_slug superset, got %s", gotState.NodeTypeSlug)
	}
	if gotState.Outcome != OutcomeMaintain {
		t.Fatalf("expected OutcomeMaintain, got %s", gotState.Outcome)
	}
	if gotState.SuggestedLoad != "0 kg / 35 kg" {
		t.Fatalf("expected '0 kg / 35 kg', got '%s'", gotState.SuggestedLoad)
	}
	if gotState.Metadata["suggested_reps_a"] != "6" {
		t.Fatalf("expected suggested_reps_a to be '6', got %v", gotState.Metadata["suggested_reps_a"])
	}
	if gotState.Metadata["suggested_reps_b"] != "6" {
		t.Fatalf("expected suggested_reps_b to be '6', got %v", gotState.Metadata["suggested_reps_b"])
	}
	if gotState.Metadata["suggested_load_b"] != "35 kg" {
		t.Fatalf("expected suggested_load_b to be '35 kg', got %v", gotState.Metadata["suggested_load_b"])
	}
}

func TestApplySessionProgression_SupersetDoubleProgressionTopHitsIncrement(t *testing.T) {
	ctx := context.Background()
	var gotState UpsertProgressionStateInput

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return []workflowBlockConfig{
				{
					ID:           20,
					Position:     0,
					NodeTypeSlug: "superset",
					Data: map[string]any{
						"exercise_a_name":    "Pull-Up (Pronated Grip)",
						"exercise_b_name":    "Barbell Squat",
						"sets":               3,
						"reps_a":             "5-8",
						"reps_b":             "5-8",
						"progression_type_a": "double",
						"progression_type_b": "double",
						"min_reps_a":         5,
						"max_reps_a":         8,
						"min_reps_b":         5,
						"max_reps_b":         8,
						"start_load_a":       0.0,
						"start_load_b":       35.0,
						"increment_a":        2.5,
						"increment_b":        2.5,
						"load_unit_a":        "kg",
						"load_unit_b":        "kg",
					},
				},
			}, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			return []ProgressionState{}, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			gotState = in
			return ProgressionState{}, nil
		},
	}

	service := NewService(repo)

	// User completes all 3 sets hitting 8 reps (max) on Barbell Squat with 35 kg!
	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     1,
		WorkflowID: 1,
		SessionID:  9,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(20), Completed: true, SetIndex: 1, ActualReps: "6/8", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(20), Completed: true, SetIndex: 2, ActualReps: "6/8", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(20), Completed: true, SetIndex: 3, ActualReps: "6/8", ActualLoad: "0/35 kg"},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if gotState.Outcome != OutcomeIncrease {
		t.Fatalf("expected OutcomeIncrease when Squat hit 8 reps, got %s", gotState.Outcome)
	}
	if gotState.SuggestedLoad != "0 kg / 37.5 kg" {
		t.Fatalf("expected '0 kg / 37.5 kg', got '%s'", gotState.SuggestedLoad)
	}
	if gotState.Metadata["suggested_reps_a"] != "7" {
		t.Fatalf("expected suggested_reps_a to be '7', got %v", gotState.Metadata["suggested_reps_a"])
	}
	if gotState.Metadata["suggested_reps_b"] != "5" {
		t.Fatalf("expected suggested_reps_b to reset to '5' after load bump, got %v", gotState.Metadata["suggested_reps_b"])
	}
	if gotState.Metadata["suggested_load_b"] != "37.5 kg" {
		t.Fatalf("expected suggested_load_b to be '37.5 kg', got %v", gotState.Metadata["suggested_load_b"])
	}
}
