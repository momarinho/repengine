package workflows

import (
	"context"
	"testing"
)

func TestNodeTypesAcceptLoadAliases(t *testing.T) {
	schemas := map[string]map[string]any{
		"exercise": {
			"exercise_name": "", "sets": 3.0, "reps": "", "rest_seconds": 90.0, "notes": "",
			"load_value": nil, "load_unit": "kg", "progression": nil, "load": nil, "target_load": nil,
		},
		"superset": {
			"exercise_a_name": "", "exercise_b_name": "", "sets": 3.0, "reps_a": "5-8", "reps_b": "5-8",
			"progression_type_a": "none", "progression_type_b": "none", "start_load_a": nil, "start_load_b": nil,
			"increment_a": 2.5, "increment_b": 2.5, "load_unit_a": "kg", "load_unit_b": "kg",
			"min_reps_a": 5.0, "max_reps_a": 8.0, "min_reps_b": 5.0, "max_reps_b": 8.0,
			"progression_rule_a": "add_each_session", "progression_rule_b": "add_each_session",
			"rest_seconds": 120.0, "notes": "",
			"load_value_a": nil, "load_value_b": nil, "load_a": nil, "load_b": nil,
			"target_load_a": nil, "target_load_b": nil,
		},
	}

	repo := &fakeRepo{
		getNodeTypeSchemaFunc: func(ctx context.Context, slug string) (map[string]any, error) {
			return schemas[slug], nil
		},
	}
	svc := NewService(repo)

	supersetBlock := WorkflowBlock{
		NodeTypeSlug: "superset",
		Data: map[string]any{
			"exercise_a_name": "Pull-Up",
			"exercise_b_name": "Lunge",
			"sets":            3.0,
			"reps_a":          "5-8",
			"reps_b":          "5-8",
			"start_load_b":    30.0,
			"load_value_b":    30.0,
			"load_unit_b":     "kg",
		},
	}
	if err := svc.validateBlock(context.Background(), supersetBlock); err != nil {
		t.Fatalf("superset block failed validation with load_value_b: %v", err)
	}

	exerciseBlock := WorkflowBlock{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": "Ab Wheel",
			"sets":          3.0,
			"reps":          "8-12",
			"load_value":    0.0,
			"target_load":   0.0,
			"load_unit":     "kg",
		},
	}
	if err := svc.validateBlock(context.Background(), exerciseBlock); err != nil {
		t.Fatalf("exercise block failed validation with target_load: %v", err)
	}
}
