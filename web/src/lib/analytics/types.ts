export interface OneRepMaxResponse {
	exercise_name: string;
	input_load: number;
	input_reps: number;
	effective_reps: number;
	brzycki_1rm: number;
	epley_1rm: number;
	mayhew_1rm: number;
	wathen_1rm: number;
	lombardi_1rm: number;
	consensus_1rm: number;
	std_dev: number;
	confidence_interval_95: [number, number];
	reps_projection: Record<number, number>;
}

export interface ACWRResponse {
	exercise_name: string | null;
	acute_workload: number;
	chronic_workload: number;
	acwr_ratio: number;
	zone: 'undertraining' | 'optimal' | 'elevated_risk' | 'danger_zone';
	risk_assessment: string;
	recommendation: string;
}

export interface INOLResponse {
	exercise_name: string;
	total_inol: number;
	classification: 'recovery' | 'optimal' | 'high_fatigue' | 'excessive';
	recovery_recommendation: string;
}

export interface AutoregulationResponse {
	exercise_name: string;
	recommended_action: 'increase_load' | 'maintain_load' | 'deload_volume' | 'deload_intensity' | 'reset_cycle';
	current_load: number;
	recommended_load: number;
	reasoning: string;
	confidence_score: number;
}

export interface PythonInsights {
	oneRepMax: OneRepMaxResponse | null;
	acwr: ACWRResponse | null;
	autoregulation: AutoregulationResponse | null;
}
