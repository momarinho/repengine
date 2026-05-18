package progressionstates

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/momarinho/rep_engine/internal/fitness"
)

type Repository struct {
	pool *pgxpool.Pool
}

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

func (r *Repository) ListWorkflowBlocks(ctx context.Context, workflowID int) ([]workflowBlockConfig, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, node_type_slug, position, data
		FROM workflow_blocks
		WHERE workflow_id = $1
		ORDER BY position ASC, id ASC
	`, workflowID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	blocks := []workflowBlockConfig{}
	for rows.Next() {
		var block workflowBlockConfig
		var rawData []byte
		if err := rows.Scan(&block.ID, &block.NodeTypeSlug, &block.Position, &rawData); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(rawData, &block.Data); err != nil {
			return nil, err
		}
		if block.Data == nil {
			block.Data = map[string]any{}
		}
		blocks = append(blocks, block)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return blocks, nil
}

func (r *Repository) ListProgressionStates(ctx context.Context, userID, workflowID int) ([]ProgressionState, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, workflow_id, COALESCE(workflow_block_id, 0), block_key,
		       node_type_slug, state_type, COALESCE(exercise_name, ''), outcome,
		       COALESCE(current_load, ''), COALESCE(suggested_load, ''),
		       COALESCE(current_week, 0), COALESCE(suggested_week, 0),
		       COALESCE(suggested_intensity_offset, ''), COALESCE(avg_actual_rpe, ''),
		       COALESCE(avg_actual_rir, ''), COALESCE(last_session_id, 0),
		       last_log_count, COALESCE(summary, ''), metadata, created_at, updated_at
		FROM progression_states
		WHERE user_id = $1 AND workflow_id = $2
		ORDER BY updated_at DESC, id DESC
	`, userID, workflowID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	states := []ProgressionState{}
	for rows.Next() {
		state, err := scanProgressionState(rows)
		if err != nil {
			return nil, err
		}
		states = append(states, state)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return states, nil
}

func (r *Repository) UpsertProgressionState(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error) {
	metadataJSON, err := json.Marshal(in.Metadata)
	if err != nil {
		return ProgressionState{}, err
	}

	currentLoadValue := fitness.OptionalFirstNumberString(in.CurrentLoad)
	suggestedLoadValue := fitness.OptionalFirstNumberString(in.SuggestedLoad)
	suggestedIntensityOffsetValue := fitness.OptionalFirstNumberString(in.SuggestedIntensityOffset)
	avgActualRPEValue := fitness.OptionalFirstNumberString(in.AvgActualRPE)
	avgActualRIRValue := fitness.OptionalFirstNumberString(in.AvgActualRIR)

	row := r.pool.QueryRow(ctx, `
		INSERT INTO progression_states (
			user_id,
			workflow_id,
			workflow_block_id,
			block_key,
			node_type_slug,
			state_type,
			exercise_name,
			outcome,
			current_load,
			suggested_load,
			current_week,
			suggested_week,
			suggested_intensity_offset,
			current_load_value,
			suggested_load_value,
			suggested_intensity_offset_value,
			avg_actual_rpe,
			avg_actual_rir,
			avg_actual_rpe_value,
			avg_actual_rir_value,
			last_session_id,
			last_log_count,
			summary,
			metadata
		)
		VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
			NULLIF($11, 0), NULLIF($12, 0), $13, $14, $15, $16, $17, $18, $19, $20,
			NULLIF($21, 0), $22, $23, $24
		)
		ON CONFLICT (user_id, workflow_id, block_key)
		DO UPDATE SET
			workflow_block_id = EXCLUDED.workflow_block_id,
			node_type_slug = EXCLUDED.node_type_slug,
			state_type = EXCLUDED.state_type,
			exercise_name = EXCLUDED.exercise_name,
			outcome = EXCLUDED.outcome,
			current_load = EXCLUDED.current_load,
			suggested_load = EXCLUDED.suggested_load,
			current_week = EXCLUDED.current_week,
			suggested_week = EXCLUDED.suggested_week,
			suggested_intensity_offset = EXCLUDED.suggested_intensity_offset,
			current_load_value = EXCLUDED.current_load_value,
			suggested_load_value = EXCLUDED.suggested_load_value,
			suggested_intensity_offset_value = EXCLUDED.suggested_intensity_offset_value,
			avg_actual_rpe = EXCLUDED.avg_actual_rpe,
			avg_actual_rir = EXCLUDED.avg_actual_rir,
			avg_actual_rpe_value = EXCLUDED.avg_actual_rpe_value,
			avg_actual_rir_value = EXCLUDED.avg_actual_rir_value,
			last_session_id = EXCLUDED.last_session_id,
			last_log_count = EXCLUDED.last_log_count,
			summary = EXCLUDED.summary,
			metadata = EXCLUDED.metadata,
			updated_at = NOW()
		RETURNING id, user_id, workflow_id, COALESCE(workflow_block_id, 0), block_key,
		          node_type_slug, state_type, COALESCE(exercise_name, ''), outcome,
		          COALESCE(current_load, ''), COALESCE(suggested_load, ''),
		          COALESCE(current_week, 0), COALESCE(suggested_week, 0),
		          COALESCE(suggested_intensity_offset, ''), COALESCE(avg_actual_rpe, ''),
		          COALESCE(avg_actual_rir, ''), COALESCE(last_session_id, 0),
		          last_log_count, COALESCE(summary, ''), metadata, created_at, updated_at
	`, in.UserID, in.WorkflowID, in.WorkflowBlockID, in.BlockKey, in.NodeTypeSlug, in.StateType,
		in.ExerciseName, in.Outcome, in.CurrentLoad, in.SuggestedLoad, in.CurrentWeek,
		in.SuggestedWeek, in.SuggestedIntensityOffset, currentLoadValue, suggestedLoadValue,
		suggestedIntensityOffsetValue, in.AvgActualRPE, in.AvgActualRIR, avgActualRPEValue,
		avgActualRIRValue, in.LastSessionID, in.LastLogCount, in.Summary, metadataJSON)

	return scanProgressionState(row)
}

func scanProgressionState(row pgx.Row) (ProgressionState, error) {
	var state ProgressionState
	var metadataJSON []byte
	err := row.Scan(
		&state.ID,
		&state.UserID,
		&state.WorkflowID,
		&state.WorkflowBlockID,
		&state.BlockKey,
		&state.NodeTypeSlug,
		&state.StateType,
		&state.ExerciseName,
		&state.Outcome,
		&state.CurrentLoad,
		&state.SuggestedLoad,
		&state.CurrentWeek,
		&state.SuggestedWeek,
		&state.SuggestedIntensityOffset,
		&state.AvgActualRPE,
		&state.AvgActualRIR,
		&state.LastSessionID,
		&state.LastLogCount,
		&state.Summary,
		&metadataJSON,
		&state.CreatedAt,
		&state.UpdatedAt,
	)
	if err != nil {
		return ProgressionState{}, err
	}

	if len(metadataJSON) > 0 {
		if err := json.Unmarshal(metadataJSON, &state.Metadata); err != nil {
			return ProgressionState{}, err
		}
	}
	if state.Metadata == nil {
		state.Metadata = map[string]any{}
	}

	return state, nil
}
