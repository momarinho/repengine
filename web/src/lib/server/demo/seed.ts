import type { NodeType, Workflow, WorkflowBlockApi, WorkflowVersion } from '$lib/editor/types';
import type { ProgressionState } from '$lib/progression-states/types';
import type { CloneJob, Template } from '$lib/templates/types';
import type { TrainingMax } from '$lib/training-maxes/types';
import type { WorkoutSession, WorkoutSetLog } from '$lib/workout-sessions/types';

export const DEMO_NODE_TYPES: NodeType[] = [
	{
		id: 1,
		slug: 'exercise',
		name: 'Exercise',
		description: 'A single exercise node',
		icon: 'dumbbell',
		schema: {
			exercise_name: '',
			sets: 3,
			reps: '',
			rest_seconds: 90,
			notes: '',
			load_value: null,
			load_unit: 'kg',
			progression: null,
			load: null,
			target_load: null,
			max_load: null,
			on_max_load: null
		}
	},
	{
		id: 2,
		slug: 'exercise_timed',
		name: 'Timed Exercise',
		description: 'Exercise with duration',
		icon: 'timer',
		schema: { exercise_name: '', duration: 30, progression: null }
	},
	{
		id: 3,
		slug: 'wave',
		name: 'Wave',
		description: 'Progressive exercise block with set-by-set intensities and week presets',
		icon: 'activity',
		schema: {
			exercise_name: '',
			active_week: 1,
			rest_seconds: 120,
			week_1_reps: '5/5/5+',
			week_1_intensity: '65/70/75',
			week_1_rpe: '7/8/9',
			week_2_reps: '3/3/3+',
			week_2_intensity: '70/75/80',
			week_2_rpe: '8/8/9',
			week_3_reps: '5/3/1+',
			week_3_intensity: '75/80/85',
			week_3_rpe: '8/9/9',
			week_4_reps: '5/5/5',
			week_4_intensity: '40/50/60',
			week_4_rpe: '6/6/6',
			week_5_reps: '',
			week_5_intensity: '',
			week_5_rpe: '',
			week_6_reps: '',
			week_6_intensity: '',
			week_6_rpe: '',
			week: '',
			intensity_percent: '',
			rpe: '',
			reps: ''
		}
	},
	{
		id: 4,
		slug: 'linear_progression',
		name: 'Linear Progression',
		description: 'Session-to-session load progression',
		icon: 'trending_up',
		schema: {
			exercise_name: '',
			sets: 3,
			reps: '5+',
			start_load: null,
			load_unit: 'kg',
			increment: 2.5,
			progression_rule: 'gzclp_standard_t1',
			rest_seconds: 180,
			fail_sequence: '3x5+ -> 5x3+ -> 6x2+',
			reset_percent: 0.85,
			rounding_precision: 2.5,
			notes: '',
			deload_weeks: null,
			deload_percent: null,
			progression: null,
			load: null,
			load_value: null,
			target_load: null,
			max_load: null,
			on_max_load: null
		}
	},
	{
		id: 5,
		slug: 'superset',
		name: 'Superset',
		description: 'Alternating pull/push or multi-exercise group',
		icon: 'layers',
		schema: {
			exercise_a_name: '',
			exercise_b_name: '',
			sets: 3,
			reps_a: '5-8',
			reps_b: '5-8',
			progression_type_a: 'none',
			progression_type_b: 'none',
			start_load_a: null,
			start_load_b: null,
			increment_a: 2.5,
			increment_b: 2.5,
			load_unit_a: 'kg',
			load_unit_b: 'kg',
			min_reps_a: 5,
			max_reps_a: 8,
			min_reps_b: 5,
			max_reps_b: 8,
			progression_rule_a: 'add_each_session',
			progression_rule_b: 'add_each_session',
			rest_seconds: 120,
			notes: '',
			load_value_a: null,
			load_value_b: null,
			load_a: null,
			load_b: null,
			target_load_a: null,
			target_load_b: null
		}
	},
	{
		id: 6,
		slug: 'repeat',
		name: 'Repeat',
		description: 'Repeat block',
		icon: 'repeat',
		schema: { title: '', times: 3, rounds: 3, reps: '', interval_phases: [] }
	},
	{
		id: 7,
		slug: 'rest',
		name: 'Rest',
		description: 'Rest period between sets',
		icon: 'pause',
		schema: { duration: 30 }
	},
	{
		id: 8,
		slug: 'section',
		name: 'Section',
		description: 'Logical section or training day divider',
		icon: 'folder',
		schema: { title: 'Day 1', subtitle: '', kind: 'day', collapsed: false, label: '' }
	},
	{
		id: 9,
		slug: 'deload',
		name: 'Deload & Recovery',
		description: 'Configures scheduled active recovery or deload parameters for routine blocks',
		icon: 'battery_charging_full',
		schema: {
			title: 'Deload & Recovery Protocol',
			frequency_weeks: 4,
			strategy: 'volume',
			volume_reduction_percent: 40,
			intensity_reduction_percent: 15,
			is_active: false,
			notes: ''
		}
	}
];

function daysAgoIso(days: number, hour = 18): string {
	const d = new Date();
	d.setUTCDate(d.getUTCDate() - days);
	d.setUTCHours(hour, 15, 0, 0);
	return d.toISOString();
}

export type DemoState = {
	workflows: Workflow[];
	versionsByWorkflow: Record<number, WorkflowVersion[]>;
	progressionStatesByWorkflow: Record<number, ProgressionState[]>;
	sessionsByWorkflow: Record<number, WorkoutSession[]>;
	templates: Template[];
	cloneJobs: Record<number, CloneJob>;
	trainingMaxes: TrainingMax[];
	nextWorkflowId: number;
	nextBlockId: number;
	nextSessionId: number;
	nextLogId: number;
	nextVersionId: number;
	nextCloneJobId: number;
};

export function createInitialDemoState(): DemoState {
	const w1Blocks: WorkflowBlockApi[] = [
		{
			id: 101,
			workflow_id: 1,
			node_type_slug: 'section',
			position: 0,
			data: { title: 'Workout A1 - Squat & Bench', subtitle: 'T1 Squat • T2 Bench • T3 Back', kind: 'day' }
		},
		{
			id: 102,
			workflow_id: 1,
			node_type_slug: 'linear_progression',
			position: 1,
			data: {
				exercise_name: 'Barbell Back Squat',
				sets: 5,
				reps: '3+',
				start_load: 65,
				load_unit: 'kg',
				increment: 2.5,
				progression_rule: 'gzclp_standard_t1',
				fail_sequence: '3x5+ -> 5x3+ -> 6x2+',
				reset_percent: 0.85,
				rounding_precision: 2.5,
				max_load: 72,
				on_max_load: 'expand_reps',
				rest_seconds: 180,
				notes: 'Home gym plate limit set to 72 kg.'
			}
		},
		{
			id: 103,
			workflow_id: 1,
			node_type_slug: 'linear_progression',
			position: 2,
			data: {
				exercise_name: 'Barbell Bench Press',
				sets: 3,
				reps: '10',
				start_load: 47.5,
				load_unit: 'kg',
				increment: 2.5,
				progression_rule: 'gzclp_standard_t2',
				fail_sequence: '3x10 -> 3x8 -> 3x6',
				reset_percent: 0.85,
				rounding_precision: 2.5,
				rest_seconds: 120,
				notes: 'Controlled eccentric, 1s pause on chest.'
			}
		},
		{
			id: 104,
			workflow_id: 1,
			node_type_slug: 'linear_progression',
			position: 3,
			data: {
				exercise_name: 'Lat Pulldown',
				sets: 3,
				reps: '15+',
				start_load: 45,
				load_unit: 'kg',
				increment: 2.5,
				progression_rule: 'gzclp_standard_t3',
				min_amrap_reps: 25,
				rest_seconds: 90,
				notes: 'Add weight once final AMRAP set hits 25+ reps.'
			}
		},
		{
			id: 105,
			workflow_id: 1,
			node_type_slug: 'section',
			position: 4,
			data: { title: 'Workout B1 - Deadlift Cap & OHP', subtitle: 'T1 Deadlift (Equipment Cap) • T2 OHP', kind: 'day' }
		},
		{
			id: 106,
			workflow_id: 1,
			node_type_slug: 'linear_progression',
			position: 5,
			data: {
				exercise_name: 'Barbell Deadlift',
				sets: 5,
				reps: '3+',
				start_load: 72,
				load_unit: 'kg',
				increment: 5,
				progression_rule: 'gzclp_standard_t1',
				fail_sequence: '3x5+ -> 5x3+ -> 6x2+',
				reset_percent: 0.85,
				rounding_precision: 2.5,
				max_load: 72,
				on_max_load: 'expand_reps',
				rest_seconds: 180,
				notes: 'Reached 72 kg barbell + plates capacity — auto rep expansion active.'
			}
		},
		{
			id: 107,
			workflow_id: 1,
			node_type_slug: 'linear_progression',
			position: 6,
			data: {
				exercise_name: 'Overhead Press',
				sets: 3,
				reps: '10',
				start_load: 32.5,
				load_unit: 'kg',
				increment: 2.5,
				progression_rule: 'gzclp_standard_t2',
				fail_sequence: '3x10 -> 3x8 -> 3x6',
				rest_seconds: 120,
				notes: 'Brace core and squeeze glutes.'
			}
		},
		{
			id: 108,
			workflow_id: 1,
			node_type_slug: 'exercise',
			position: 7,
			data: {
				exercise_name: 'Single-Arm Dumbbell Row',
				sets: 3,
				reps: '8-12',
				load_value: 24,
				load_unit: 'kg',
				rest_seconds: 90,
				notes: 'Double progression: progress from 8 to 12 reps before increasing load.',
				progression: { type: 'double', min_reps: 8, max_reps: 12, increment: 2 }
			}
		}
	];

	const w2Blocks: WorkflowBlockApi[] = [
		{
			id: 201,
			workflow_id: 2,
			node_type_slug: 'section',
			position: 0,
			data: { title: 'Day 1 - Wave Squat & Calisthenics', subtitle: '5/3/1 Undulating Wave + Superset', kind: 'day' }
		},
		{
			id: 202,
			workflow_id: 2,
			node_type_slug: 'wave',
			position: 1,
			data: {
				exercise_name: 'Barbell Back Squat',
				active_week: 2,
				rest_seconds: 150,
				week_1_reps: '5/5/5+',
				week_1_intensity: '65/70/75',
				week_1_rpe: '7/7.5/8.5',
				week_2_reps: '3/3/3+',
				week_2_intensity: '70/75/80',
				week_2_rpe: '7.5/8/9',
				week_3_reps: '5/3/1+',
				week_3_intensity: '75/80/85',
				week_3_rpe: '8/8.5/9.5',
				week_4_reps: '5/5/5',
				week_4_intensity: '40/50/60',
				week_4_rpe: '6/6/6'
			}
		},
		{
			id: 203,
			workflow_id: 2,
			node_type_slug: 'superset',
			position: 2,
			data: {
				exercise_a_name: 'Weighted Pull-ups',
				exercise_b_name: 'Weighted Dips',
				sets: 3,
				reps_a: '6-10',
				reps_b: '8-12',
				progression_type_a: 'double',
				progression_type_b: 'double',
				start_load_a: 10,
				start_load_b: 12.5,
				increment_a: 2.5,
				increment_b: 2.5,
				load_unit_a: 'kg',
				load_unit_b: 'kg',
				min_reps_a: 6,
				max_reps_a: 10,
				min_reps_b: 8,
				max_reps_b: 12,
				rest_seconds: 120,
				notes: '45s transition between pull-ups and dips.'
			}
		},
		{
			id: 204,
			workflow_id: 2,
			node_type_slug: 'section',
			position: 3,
			data: { title: 'Day 2 - Wave Bench & Core', subtitle: '5/3/1 Bench + Timed Core', kind: 'day' }
		},
		{
			id: 205,
			workflow_id: 2,
			node_type_slug: 'wave',
			position: 4,
			data: {
				exercise_name: 'Barbell Bench Press',
				active_week: 2,
				rest_seconds: 150,
				week_1_reps: '5/5/5+',
				week_1_intensity: '65/70/75',
				week_1_rpe: '7/8/8.5',
				week_2_reps: '3/3/3+',
				week_2_intensity: '70/75/80',
				week_2_rpe: '8/8.5/9',
				week_3_reps: '5/3/1+',
				week_3_intensity: '75/80/85',
				week_3_rpe: '8.5/9/9.5',
				week_4_reps: '5/5/5',
				week_4_intensity: '40/50/60',
				week_4_rpe: '6/6/6'
			}
		},
		{
			id: 206,
			workflow_id: 2,
			node_type_slug: 'exercise_timed',
			position: 5,
			data: { exercise_name: 'RKC Plank Hold', duration: 45 }
		},
		{
			id: 207,
			workflow_id: 2,
			node_type_slug: 'deload',
			position: 6,
			data: {
				title: 'Week 4 Recovery Protocol',
				frequency_weeks: 4,
				strategy: 'intensity',
				volume_reduction_percent: 30,
				intensity_reduction_percent: 20,
				is_active: false,
				notes: 'Automatically triggers on Week 4.'
			}
		}
	];

	const w3Blocks: WorkflowBlockApi[] = [
		{
			id: 301,
			workflow_id: 3,
			node_type_slug: 'section',
			position: 0,
			data: { title: 'Upper Hypertrophy', subtitle: 'Chest, Back & Arms', kind: 'day' }
		},
		{
			id: 302,
			workflow_id: 3,
			node_type_slug: 'exercise',
			position: 1,
			data: {
				exercise_name: 'Incline Dumbbell Press',
				sets: 3,
				reps: '8-12',
				load_value: 26,
				load_unit: 'kg',
				rest_seconds: 90,
				notes: 'Full stretch at the bottom.',
				progression: { type: 'double', min_reps: 8, max_reps: 12, increment: 2 }
			}
		},
		{
			id: 303,
			workflow_id: 3,
			node_type_slug: 'rest',
			position: 2,
			data: { duration: 120 }
		},
		{
			id: 304,
			workflow_id: 3,
			node_type_slug: 'superset',
			position: 3,
			data: {
				exercise_a_name: 'Cable Lateral Raise',
				exercise_b_name: 'Face Pull',
				sets: 3,
				reps_a: '12-15',
				reps_b: '15-20',
				progression_type_a: 'double',
				progression_type_b: 'double',
				start_load_a: 7.5,
				start_load_b: 17.5,
				increment_a: 2.5,
				increment_b: 2.5,
				load_unit_a: 'kg',
				load_unit_b: 'kg',
				min_reps_a: 12,
				max_reps_a: 15,
				min_reps_b: 15,
				max_reps_b: 20,
				rest_seconds: 75,
				notes: 'Keep scapulae controlled.'
			}
		}
	];

	const workflows: Workflow[] = [
		{
			id: 1,
			user_id: 1,
			name: 'GZCLP Home Gym (72 kg Cap)',
			description: '4-day linear progression with GZCLP failure sequences and automatic rep expansion when hitting the 72 kg barbell/plate ceiling.',
			is_public: true,
			created_at: daysAgoIso(21),
			updated_at: daysAgoIso(1),
			blocks: w1Blocks
		},
		{
			id: 2,
			user_id: 1,
			name: '5/3/1 Wave & Calisthenics',
			description: 'Percentage-based undulating wave periodization synced to Training Maxes, paired with weighted calisthenics supersets.',
			is_public: true,
			created_at: daysAgoIso(30),
			updated_at: daysAgoIso(3),
			blocks: w2Blocks
		},
		{
			id: 3,
			user_id: 1,
			name: 'Upper Hypertrophy Express',
			description: 'Focused double-progression hypertrophy session with supersets and timed rests.',
			is_public: false,
			created_at: daysAgoIso(10),
			updated_at: daysAgoIso(5),
			blocks: w3Blocks
		}
	];

	const progressionStatesByWorkflow: Record<number, ProgressionState[]> = {
		1: [
			{
				id: 1,
				user_id: 1,
				workflow_id: 1,
				workflow_block_id: 102,
				block_key: '::linear_progression::barbell_back_squat::1',
				node_type_slug: 'linear_progression',
				state_type: 'linear',
				exercise_name: 'Barbell Back Squat',
				outcome: 'increase',
				current_load: '62.5 kg',
				suggested_load: '65 kg',
				current_week: 0,
				suggested_week: 0,
				suggested_intensity_offset: '',
				avg_actual_rpe: '8.0',
				avg_actual_rir: '2.0',
				last_session_id: 1003,
				last_log_count: 5,
				summary: 'Completed all 5 sets of 3+ at 62.5 kg! Adding load next session (65 kg).',
				metadata: {
					sets_planned: 5,
					reps_planned: '3+',
					target_reps_lower: 3,
					target_reps_upper: 3,
					current_sequence_index: 1,
					fail_sequence: '3x5+ -> 5x3+ -> 6x2+',
					max_load: 72,
					on_max_load: 'expand_reps',
					capped: false
				},
				created_at: daysAgoIso(3),
				updated_at: daysAgoIso(3)
			},
			{
				id: 2,
				user_id: 1,
				workflow_id: 1,
				workflow_block_id: 103,
				block_key: '::linear_progression::barbell_bench_press::2',
				node_type_slug: 'linear_progression',
				state_type: 'linear',
				exercise_name: 'Barbell Bench Press',
				outcome: 'increase',
				current_load: '45 kg',
				suggested_load: '47.5 kg',
				current_week: 0,
				suggested_week: 0,
				suggested_intensity_offset: '',
				avg_actual_rpe: '8.0',
				avg_actual_rir: '2.0',
				last_session_id: 1003,
				last_log_count: 3,
				summary: 'Completed all 3x10 at 45 kg. Adding load next session (47.5 kg).',
				metadata: {
					sets_planned: 3,
					reps_planned: '10',
					target_reps_lower: 10,
					target_reps_upper: 10,
					current_sequence_index: 0,
					fail_sequence: '3x10 -> 3x8 -> 3x6'
				},
				created_at: daysAgoIso(3),
				updated_at: daysAgoIso(3)
			},
			{
				id: 3,
				user_id: 1,
				workflow_id: 1,
				workflow_block_id: 106,
				block_key: '::linear_progression::barbell_deadlift::5',
				node_type_slug: 'linear_progression',
				state_type: 'linear',
				exercise_name: 'Barbell Deadlift',
				outcome: 'increase',
				current_load: '72 kg',
				suggested_load: '72 kg',
				current_week: 0,
				suggested_week: 0,
				suggested_intensity_offset: '',
				avg_actual_rpe: '8.5',
				avg_actual_rir: '1.5',
				last_session_id: 1004,
				last_log_count: 5,
				summary: 'Completed all sets at max equipment load (72 kg). Advancing to rep progression: target increased to 4 reps!',
				metadata: {
					sets_planned: 5,
					reps_planned: '4+',
					target_reps_lower: 4,
					target_reps_upper: 4,
					current_sequence_index: 1,
					fail_sequence: '3x5+ -> 5x3+ -> 6x2+',
					max_load: 72,
					on_max_load: 'expand_reps',
					capped: true,
					capped_reps: 4
				},
				created_at: daysAgoIso(1),
				updated_at: daysAgoIso(1)
			}
		],
		2: [
			{
				id: 4,
				user_id: 1,
				workflow_id: 2,
				workflow_block_id: 202,
				block_key: '::wave::barbell_back_squat::1',
				node_type_slug: 'wave',
				state_type: 'wave',
				exercise_name: 'Barbell Back Squat',
				outcome: 'advance',
				current_load: '65/70/75%',
				suggested_load: '70/75/80%',
				current_week: 1,
				suggested_week: 2,
				suggested_intensity_offset: '+5%',
				avg_actual_rpe: '8.0',
				avg_actual_rir: '2.0',
				last_session_id: 2001,
				last_log_count: 3,
				summary: 'Week 1 completed cleanly (8 reps on 5+ AMRAP). Advancing to Week 2 (3/3/3+).',
				metadata: {},
				created_at: daysAgoIso(3),
				updated_at: daysAgoIso(3)
			}
		],
		3: []
	};

	const makeLogs = (
		sessionId: number,
		blockId: number,
		clientId: string,
		slug: string,
		sets: number,
		reps: string,
		load: string,
		rpe: string,
		daysAgo: number
	): WorkoutSetLog[] =>
		Array.from({ length: sets }, (_, idx) => ({
			id: sessionId * 100 + idx + 1,
			session_id: sessionId,
			workflow_block_id: blockId,
			block_client_id: clientId,
			node_type_slug: slug,
			set_index: idx + 1,
			prescribed_reps: idx === sets - 1 ? `${reps}+` : reps,
			prescribed_load: load,
			prescribed_intensity: '',
			prescribed_rpe: rpe,
			actual_reps: idx === sets - 1 ? String(parseInt(reps, 10) + 2) : reps,
			actual_load: load,
			actual_rpe: rpe,
			actual_rir: String(Math.max(0, 10 - Math.round(parseFloat(rpe)))),
			completed: true,
			notes: '',
			created_at: daysAgoIso(daysAgo)
		}));

	const w1Sessions: WorkoutSession[] = [
		{
			id: 1004,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-1',
			section_title: 'Workout B1 - Deadlift Cap & OHP',
			status: 'completed',
			started_at: daysAgoIso(1, 18),
			completed_at: daysAgoIso(1, 19),
			notes: 'Hit 72 kg plate ceiling on Deadlift for 5x3+ (6 on AMRAP). System shifted next session to 5x4+.',
			log_count: 8,
			logs: [
				...makeLogs(1004, 106, 'block-106', 'linear_progression', 5, '3', '72 kg', '8.5', 1),
				...makeLogs(1004, 107, 'block-107', 'linear_progression', 3, '10', '30 kg', '8.0', 1)
			]
		},
		{
			id: 1003,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-0',
			section_title: 'Workout A1 - Squat & Bench',
			status: 'completed',
			started_at: daysAgoIso(3, 18),
			completed_at: daysAgoIso(3, 19),
			notes: 'Squat felt snappy at 62.5 kg.',
			log_count: 8,
			logs: [
				...makeLogs(1003, 102, 'block-102', 'linear_progression', 5, '3', '62.5 kg', '8.0', 3),
				...makeLogs(1003, 103, 'block-103', 'linear_progression', 3, '10', '45 kg', '8.0', 3)
			]
		},
		{
			id: 1002,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-1',
			section_title: 'Workout B1 - Deadlift Cap & OHP',
			status: 'completed',
			started_at: daysAgoIso(6, 18),
			completed_at: daysAgoIso(6, 19),
			notes: '70 kg deadlift — next bump hits 72 kg max load.',
			log_count: 8,
			logs: [
				...makeLogs(1002, 106, 'block-106', 'linear_progression', 5, '3', '70 kg', '8.0', 6),
				...makeLogs(1002, 107, 'block-107', 'linear_progression', 3, '10', '27.5 kg', '7.5', 6)
			]
		},
		{
			id: 1001,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-0',
			section_title: 'Workout A1 - Squat & Bench',
			status: 'completed',
			started_at: daysAgoIso(9, 18),
			completed_at: daysAgoIso(9, 19),
			notes: 'Smooth baseline week.',
			log_count: 8,
			logs: [
				...makeLogs(1001, 102, 'block-102', 'linear_progression', 5, '3', '60 kg', '7.5', 9),
				...makeLogs(1001, 103, 'block-103', 'linear_progression', 3, '10', '42.5 kg', '7.5', 9)
			]
		},
		{
			id: 1000,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-1',
			section_title: 'Workout B1 - Deadlift Cap & OHP',
			status: 'completed',
			started_at: daysAgoIso(12, 18),
			completed_at: daysAgoIso(12, 19),
			notes: 'Good bar speed.',
			log_count: 5,
			logs: makeLogs(1000, 106, 'block-106', 'linear_progression', 5, '3', '65 kg', '7.5', 12)
		}
	];

	const w2Sessions: WorkoutSession[] = [
		{
			id: 2001,
			workflow_id: 2,
			user_id: 1,
			section_id: 'sec-0',
			section_title: 'Day 1 - Wave Squat & Calisthenics',
			status: 'completed',
			started_at: daysAgoIso(3, 17),
			completed_at: daysAgoIso(3, 18),
			notes: 'Week 1 completed cleanly.',
			log_count: 3,
			logs: makeLogs(2001, 202, 'block-202', 'wave', 3, '5', '86 kg', '8.0', 3)
		}
	];

	const templates: Template[] = [
		{
			id: 1,
			name: 'GZCLP 4-Day Linear Progression',
			description: 'Classic Tier 1 / Tier 2 / Tier 3 linear progression with automatic failure stage transitions (3x5+ → 5x3+ → 6x2+).',
			category: 'Strength',
			is_official: true,
			author_id: null,
			metadata: { difficulty: 'Beginner / Intermediate', days_per_week: 4 },
			created_at: daysAgoIso(60),
			blocks: w1Blocks.map((b, i) => ({
				id: 500 + i,
				template_id: 1,
				node_type_slug: b.node_type_slug,
				position: i,
				data: b.data ?? {},
				created_at: daysAgoIso(60)
			}))
		},
		{
			id: 2,
			name: '5/3/1 Undulating Wave Cycle',
			description: 'Four-week percentage wave loading tied to your Training Maxes, including built-in Week 4 deload.',
			category: 'Powerbuilding',
			is_official: true,
			author_id: null,
			metadata: { difficulty: 'Intermediate', days_per_week: 4 },
			created_at: daysAgoIso(55),
			blocks: w2Blocks.map((b, i) => ({
				id: 600 + i,
				template_id: 2,
				node_type_slug: b.node_type_slug,
				position: i,
				data: b.data ?? {},
				created_at: daysAgoIso(55)
			}))
		},
		{
			id: 3,
			name: 'Home Gym Cap-Safe Hypertrophy',
			description: 'Configured with equipment load limits (max_load) so progress seamlessly shifts into rep expansion when plates run out.',
			category: 'Hypertrophy',
			is_official: true,
			author_id: null,
			metadata: { difficulty: 'All Levels', days_per_week: 3 },
			created_at: daysAgoIso(40),
			blocks: w3Blocks.map((b, i) => ({
				id: 700 + i,
				template_id: 3,
				node_type_slug: b.node_type_slug,
				position: i,
				data: b.data ?? {},
				created_at: daysAgoIso(40)
			}))
		}
	];

	const versionsByWorkflow: Record<number, WorkflowVersion[]> = {
		1: [
			{
				id: 11,
				workflow_id: 1,
				version_number: 2,
				snapshot: { name: workflows[0].name, blocks: w1Blocks },
				commit_message: 'Added 72 kg home gym max_load cap & rep progression mode',
				created_at: daysAgoIso(2)
			},
			{
				id: 10,
				workflow_id: 1,
				version_number: 1,
				snapshot: { name: workflows[0].name, blocks: w1Blocks },
				commit_message: 'Initial GZCLP 4-day setup',
				created_at: daysAgoIso(21)
			}
		],
		2: [
			{
				id: 20,
				workflow_id: 2,
				version_number: 1,
				snapshot: { name: workflows[1].name, blocks: w2Blocks },
				commit_message: 'Initial 5/3/1 Wave configuration',
				created_at: daysAgoIso(30)
			}
		],
		3: []
	};

	const trainingMaxes: TrainingMax[] = [
		{ id: 1, user_id: 1, exercise_name: 'Barbell Back Squat', value: 115, unit: 'kg', updated_at: daysAgoIso(4) },
		{ id: 2, user_id: 1, exercise_name: 'Barbell Bench Press', value: 85, unit: 'kg', updated_at: daysAgoIso(4) },
		{ id: 3, user_id: 1, exercise_name: 'Barbell Deadlift', value: 130, unit: 'kg', updated_at: daysAgoIso(4) },
		{ id: 4, user_id: 1, exercise_name: 'Overhead Press', value: 55, unit: 'kg', updated_at: daysAgoIso(4) }
	];

	return {
		workflows,
		versionsByWorkflow,
		progressionStatesByWorkflow,
		sessionsByWorkflow: {
			1: w1Sessions,
			2: w2Sessions,
			3: []
		},
		templates,
		cloneJobs: {},
		trainingMaxes,
		nextWorkflowId: 10,
		nextBlockId: 1000,
		nextSessionId: 3000,
		nextLogId: 90000,
		nextVersionId: 100,
		nextCloneJobId: 1
	};
}
