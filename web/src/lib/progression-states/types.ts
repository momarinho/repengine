export type ProgressionStateType = 'linear' | 'wave' | 'skill';
export type ProgressionOutcome = 'increase' | 'maintain' | 'reduce' | 'advance' | 'regress';

export type ProgressionState = {
	id: number;
	user_id: number;
	workflow_id: number;
	workflow_block_id: number;
	block_key: string;
	node_type_slug: string;
	state_type: ProgressionStateType;
	exercise_name: string;
	outcome: ProgressionOutcome;
	current_load: string;
	suggested_load: string;
	current_week: number;
	suggested_week: number;
	suggested_intensity_offset: string;
	avg_actual_rpe: string;
	avg_actual_rir: string;
	last_session_id: number;
	last_log_count: number;
	summary: string;
	metadata: Record<string, unknown>;
	created_at: string;
	updated_at: string;
};
