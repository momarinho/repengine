export type PlayerBlockType =
	| 'section'
	| 'exercise'
	| 'linear_progression'
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
	increment?: number;
	progressionRule?: string;
	rounds?: number;
	restSeconds?: number;
	waveSteps?: WaveWeek[];
	activeWaveWeekIndex?: number;
	sectionID?: string;
	sectionTitle?: string;
	sectionSubtitle?: string;
	sectionKind?: string;
	notePlaceholder?: string;
};

export type PlayerSection = {
	id: string;
	title: string;
	subtitle: string;
	kind: string;
	startBlockIndex: number;
	blockCount: number;
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
	sections: PlayerSection[];
	blocks: PlayerBlock[];
};
