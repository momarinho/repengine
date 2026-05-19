export type WorkoutSessionStatus = 'active' | 'completed' | 'abandoned';

export type WorkoutSetLog = {
	id: number;
	session_id: number;
	workflow_block_id: number | null;
	block_client_id: string;
	node_type_slug: string;
	set_index: number;
	prescribed_reps: string;
	prescribed_load: string;
	prescribed_intensity: string;
	prescribed_rpe: string;
	actual_reps: string;
	actual_load: string;
	actual_rpe: string;
	actual_rir: string;
	completed: boolean;
	notes: string;
	created_at: string;
};

export type WorkoutSession = {
	id: number;
	workflow_id: number;
	user_id: number;
	section_id: string;
	section_title: string;
	status: WorkoutSessionStatus;
	started_at: string;
	completed_at: string | null;
	notes: string;
	log_count: number;
	logs?: WorkoutSetLog[];
};

export type PaginatedWorkoutSessions = {
	data: WorkoutSession[];
	next_cursor: number | null;
	has_more: boolean;
};

export type WorkoutAnalytics = {
	workflow_id: number;
	completed_sessions: number;
	abandoned_sessions: number;
	total_logged_sets: number;
	total_volume: number;
	average_rpe: number | null;
	average_rir: number | null;
	last_completed_at: string | null;
};
