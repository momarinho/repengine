package progressionstates

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
)

func TestLiveSimulation_YourWorkout(t *testing.T) {
	ctx := context.Background()

	blockID := 20
	blocks := []workflowBlockConfig{
		{
			ID:           blockID,
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
	}

	var lastSaved ProgressionState

	repo := &fakeRepo{
		userOwnsWorkflowFunc: func(ctx context.Context, userID, workflowID int) (bool, error) {
			return true, nil
		},
		listWorkflowBlocksFunc: func(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
			return blocks, nil
		},
		listProgressionStatesFunc: func(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
			if lastSaved.WorkflowBlockID != 0 {
				return []ProgressionState{lastSaved}, nil
			}
			return []ProgressionState{}, nil
		},
		upsertProgressionStateFunc: func(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
			lastSaved = progressionStateFromUpsert(in)
			return lastSaved, nil
		},
	}

	service := NewService(repo)

	fmt.Println("\n=================================================================")
	fmt.Println("🚀 SIMULAÇÃO 1: Treino 1 (Você fez 3x 5 reps com 0 kg / 35 kg)")
	fmt.Println("=================================================================")
	err := service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     1,
		WorkflowID: 10,
		SessionID:  1,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 1, ActualReps: "5/5", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 2, ActualReps: "5/5", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 3, ActualReps: "5/5", ActualLoad: "0/35 kg"},
		},
	})
	if err != nil {
		t.Fatalf("Erro na simulação 1: %v", err)
	}

	s1 := lastSaved
	fmt.Printf("✓ Desfecho: %s (Mantém a carga)\n", s1.Outcome)
	fmt.Printf("✓ Carga Prescrita: %s\n", s1.SuggestedLoad)
	fmt.Printf("✓ Pull-Up Meta Reps: %v (avança para tentar %v reps)\n", s1.Metadata["suggested_reps_a"], s1.Metadata["suggested_reps_a"])
	fmt.Printf("✓ Squat Meta Reps: %v (avança para tentar %v reps com 35 kg)\n", s1.Metadata["suggested_reps_b"], s1.Metadata["suggested_reps_b"])
	fmt.Printf("✓ Resumo: %s\n", s1.Summary)

	fmt.Println("\n=================================================================")
	fmt.Println("🚀 SIMULAÇÃO 2: Treino 2 (Você avançou para 6 reps na barra e 7 no agachamento)")
	fmt.Println("=================================================================")
	err = service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     1,
		WorkflowID: 10,
		SessionID:  2,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 1, ActualReps: "6/7", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 2, ActualReps: "6/7", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 3, ActualReps: "6/7", ActualLoad: "0/35 kg"},
		},
	})
	if err != nil {
		t.Fatalf("Erro na simulação 2: %v", err)
	}

	s2 := lastSaved
	fmt.Printf("✓ Desfecho: %s\n", s2.Outcome)
	fmt.Printf("✓ Carga Prescrita: %s\n", s2.SuggestedLoad)
	fmt.Printf("✓ Pull-Up Meta Reps: %v (avança para tentar 7 reps)\n", s2.Metadata["suggested_reps_a"])
	fmt.Printf("✓ Squat Meta Reps: %v (avança para tentar 8 reps com 35 kg)\n", s2.Metadata["suggested_reps_b"])
	fmt.Printf("✓ Resumo: %s\n", s2.Summary)

	fmt.Println("\n=================================================================")
	fmt.Println("🚀 SIMULAÇÃO 3: Treino 3 (Você bateu o TETO de 8 reps em todas as séries no Squat!)")
	fmt.Println("=================================================================")
	err = service.ApplySessionProgression(ctx, ApplySessionProgressionInput{
		UserID:     1,
		WorkflowID: 10,
		SessionID:  3,
		Logs: []CompletedSetLog{
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 1, ActualReps: "7/8", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 2, ActualReps: "7/8", ActualLoad: "0/35 kg"},
			{WorkflowBlockID: intPtr(blockID), Completed: true, SetIndex: 3, ActualReps: "7/8", ActualLoad: "0/35 kg"},
		},
	})
	if err != nil {
		t.Fatalf("Erro na simulação 3: %v", err)
	}

	s3 := lastSaved
	fmt.Printf("✓ Desfecho: %s (SUBIU DE CARGA!)\n", s3.Outcome)
	fmt.Printf("✓ Carga Anterior: %s\n", s3.CurrentLoad)
	fmt.Printf("✓ NOVA CARGA PREVENTIVA SUGERIDA: %s\n", s3.SuggestedLoad)
	fmt.Printf("✓ Nova Carga Squat isolada: %v (+2.5 kg)\n", s3.Metadata["suggested_load_b"])
	fmt.Printf("✓ Nova Meta Reps Squat: %v reps (resetou de 8 para a base de 5)\n", s3.Metadata["suggested_reps_b"])
	fmt.Printf("✓ Resumo: %s\n", s3.Summary)

	fmt.Println("\n=================================================================")
	fmt.Println("📄 PAYLOAD COMPLETO SALVO NO BANCO (JSON que a API retorna):")
	fmt.Println("=================================================================")
	jsonBytes, _ := json.MarshalIndent(s3, "", "  ")
	fmt.Println(string(jsonBytes))
	fmt.Println("=================================================================")
}
