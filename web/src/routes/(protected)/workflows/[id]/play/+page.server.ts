import type { PageServerLoad } from './$types';
import type { PlayerRoutine } from '$lib/player/types';

function buildMockRoutine(idParam: string): PlayerRoutine {
	const workflowID = Number.parseInt(idParam, 10);
	const routineID = Number.isNaN(workflowID) ? 1 : workflowID;

	return {
		id: routineID,
		name: 'Morning Power Routine',
		description: 'Structured strength and hypertrophy session with alternating push work and recovery.',
		focus: 'Miofibrilar hypertrophy',
		totalMinutes: 45,
		elapsedSeconds: 32 * 60 + 15,
		totalVolume: '4,520 kg',
		averageIntensity: 'RPE 8.5',
		peakHeartRate: '142 bpm',
		initialBlockIndex: 3,
		blocks: [
			{
				id: 'section-activation',
				node_type_slug: 'section',
				title: 'Activation Series',
				subtitle: 'Prime shoulders and upper back before the working sets.',
				eyebrow: 'Section',
				tone: 'muted'
			},
			{
				id: 'exercise-bench',
				node_type_slug: 'exercise',
				title: 'Barbell Bench Press',
				subtitle: 'Chest, triceps, anterior deltoid',
				eyebrow: 'Main lift',
				tone: 'primary',
				sets: 4,
				reps: '5',
				load: 100,
				loadUnit: 'kg',
				restSeconds: 120,
				notePlaceholder: 'Tempo, bar path, or RPE notes...'
			},
			{
				id: 'rest-bench',
				node_type_slug: 'rest',
				title: 'Rest Block',
				subtitle: 'Recover before the incline work.',
				eyebrow: 'Rest',
				tone: 'secondary',
				durationSeconds: 90
			},
			{
				id: 'exercise-incline',
				node_type_slug: 'exercise',
				title: 'Incline Dumbbell Press',
				subtitle: 'Chest, anterior deltoid',
				eyebrow: 'Active block',
				tone: 'tertiary',
				sets: 4,
				reps: '8-10',
				load: 42,
				loadUnit: 'kg',
				restSeconds: 75,
				notePlaceholder: 'Example: RPE 8, controlled eccentric...'
			},
			{
				id: 'wave-ohp',
				node_type_slug: 'wave',
				title: 'Overhead Press Wave',
				subtitle: '4-week 5/3/1 progression',
				eyebrow: 'Wave',
				tone: 'secondary',
				waveSteps: [
					{ label: 'Week 1', reps: '5 / 5 / 5+', intensity: '65 / 75 / 85%', rpe: '8' },
					{ label: 'Week 2', reps: '3 / 3 / 3+', intensity: '70 / 80 / 90%', rpe: '8.5' },
					{ label: 'Week 3', reps: '5 / 3 / 1+', intensity: '75 / 85 / 95%', rpe: '9' },
					{ label: 'Deload', reps: '5 / 5 / 5', intensity: '40 / 50 / 60%', rpe: '6' }
				]
			},
			{
				id: 'repeat-lateral',
				node_type_slug: 'repeat',
				title: 'Lateral Raise Giant Set',
				subtitle: 'Accumulate clean volume for the shoulders.',
				eyebrow: 'Repeat',
				tone: 'secondary',
				rounds: 3,
				reps: '15 reps each round',
				notePlaceholder: 'Track burn, tempo, or partial reps...'
			},
			{
				id: 'timed-bike',
				node_type_slug: 'exercise_timed',
				title: 'Bike Sprint',
				subtitle: 'Finisher interval on the assault bike.',
				eyebrow: 'Timed effort',
				tone: 'primary',
				durationSeconds: 40,
				reps: 'All-out',
				notePlaceholder: 'Breathing, pace, or watts...'
			},
			{
				id: 'section-recovery',
				node_type_slug: 'section',
				title: 'Cooldown',
				subtitle: 'Down-regulate and finish with shoulder mobility.',
				eyebrow: 'Section',
				tone: 'muted'
			}
		]
	};
}

export const load = (async ({ params }) => {
	return {
		routine: buildMockRoutine(params.id)
	};
}) satisfies PageServerLoad;
