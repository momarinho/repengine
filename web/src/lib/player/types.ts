export type PlayerBlockType =
	| 'section'
	| 'exercise'
	| 'rest'
	| 'wave'
	| 'repeat'
	| 'exercise_timed';

export type QueueTone = 'primary' | 'secondary' | 'tertiary' | 'muted';

export type WaveStep = {
	label: string;
	reps: string;
	intensity: string;
	rpe: string;
};

export type WaveSetPrescription = {
	label: string;
	reps: string;
	intensity: string;
	rpe: string;
};

export type WaveWeek = WaveStep & {
	prescriptions: WaveSetPrescription[];
};

export type PlayerBlock = {
	id: string;
	node_type_slug: PlayerBlockType;
	title: string;
	subtitle: string;
	eyebrow?: string;
	tone?: QueueTone;
	durationSeconds?: number;
	sets?: number;
	reps?: string;
	load?: number;
	loadUnit?: string;
	rounds?: number;
	restSeconds?: number;
	waveSteps?: WaveWeek[];
	activeWaveWeekIndex?: number;
	notePlaceholder?: string;
};

export type PlayerRoutine = {
	id: number;
	name: string;
	description: string;
	focus: string;
	totalMinutes: number;
	elapsedSeconds: number;
	totalVolume: string;
	averageIntensity: string;
	peakHeartRate: string;
	initialBlockIndex: number;
	blocks: PlayerBlock[];
};
