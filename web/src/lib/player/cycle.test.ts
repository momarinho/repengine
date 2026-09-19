import test from 'node:test';
import assert from 'node:assert/strict';
import { getNextAndLastCompletedSection, getSectionExercisePreview, formatRelativeDate } from './cycle.ts';
import type { PlayerSection, PlayerBlock } from './types.ts';
import type { WorkoutSession } from '../workout-sessions/types.ts';

const mockSections: PlayerSection[] = [
	{ id: 'sec-1', title: 'Day A - Chest & Triceps', subtitle: '', kind: 'day', startBlockIndex: 0, blockCount: 3 },
	{ id: 'sec-2', title: 'Day B - Back & Biceps', subtitle: '', kind: 'day', startBlockIndex: 3, blockCount: 3 },
	{ id: 'sec-3', title: 'Day C - Legs & Shoulders', subtitle: '', kind: 'day', startBlockIndex: 6, blockCount: 3 }
];

test('returns first section when no session history exists', () => {
	const result = getNextAndLastCompletedSection(mockSections, []);
	assert.equal(result.nextSection?.id, 'sec-1');
	assert.equal(result.lastCompletedSection, null);
	assert.equal(result.nextIndex, 0);
});

test('returns next section in sequence when a session is completed', () => {
	const history: WorkoutSession[] = [
		{
			id: 10,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-1',
			section_title: 'Day A - Chest & Triceps',
			status: 'completed',
			started_at: new Date().toISOString(),
			completed_at: new Date().toISOString(),
			notes: '',
			log_count: 5
		}
	];

	const result = getNextAndLastCompletedSection(mockSections, history);
	assert.equal(result.nextSection?.id, 'sec-2');
	assert.equal(result.lastCompletedSection?.id, 'sec-1');
	assert.equal(result.nextIndex, 1);
});

test('cycles back to first section after last section is completed', () => {
	const history: WorkoutSession[] = [
		{
			id: 12,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-3',
			section_title: 'Day C - Legs & Shoulders',
			status: 'completed',
			started_at: new Date().toISOString(),
			completed_at: new Date().toISOString(),
			notes: '',
			log_count: 5
		}
	];

	const result = getNextAndLastCompletedSection(mockSections, history);
	assert.equal(result.nextSection?.id, 'sec-1');
	assert.equal(result.lastCompletedSection?.id, 'sec-3');
	assert.equal(result.nextIndex, 0);
});

test('matches by section title fallback if section_id changed', () => {
	const history: WorkoutSession[] = [
		{
			id: 15,
			workflow_id: 1,
			user_id: 1,
			section_id: 'old-random-id',
			section_title: 'Day B - Back & Biceps',
			status: 'completed',
			started_at: new Date().toISOString(),
			completed_at: new Date().toISOString(),
			notes: '',
			log_count: 5
		}
	];

	const result = getNextAndLastCompletedSection(mockSections, history);
	assert.equal(result.nextSection?.id, 'sec-3');
	assert.equal(result.lastCompletedSection?.id, 'sec-2');
});

test('ignores abandoned sessions when finding next section', () => {
	const history: WorkoutSession[] = [
		{
			id: 20,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-2',
			section_title: 'Day B - Back & Biceps',
			status: 'abandoned',
			started_at: new Date().toISOString(),
			completed_at: null,
			notes: '',
			log_count: 1
		},
		{
			id: 19,
			workflow_id: 1,
			user_id: 1,
			section_id: 'sec-1',
			section_title: 'Day A - Chest & Triceps',
			status: 'completed',
			started_at: new Date().toISOString(),
			completed_at: new Date().toISOString(),
			notes: '',
			log_count: 5
		}
	];

	const result = getNextAndLastCompletedSection(mockSections, history);
	assert.equal(result.nextSection?.id, 'sec-2');
	assert.equal(result.lastCompletedSection?.id, 'sec-1');
});

test('extracts exercise preview names skipping rests', () => {
	const blocks: PlayerBlock[] = [
		{ id: '1', node_type_slug: 'exercise', title: 'Bench Press', subtitle: '', eyebrow: '', tone: 'primary' },
		{ id: '2', node_type_slug: 'rest', title: 'Rest', subtitle: '', eyebrow: '', tone: 'muted' },
		{ id: '3', node_type_slug: 'exercise', title: 'Incline Dumbbell Press', subtitle: '', eyebrow: '', tone: 'primary' },
		{ id: '4', node_type_slug: 'exercise', title: 'Triceps Pushdown', subtitle: '', eyebrow: '', tone: 'primary' }
	];

	const section: PlayerSection = {
		id: 'sec-1',
		title: 'Day A',
		subtitle: '',
		kind: 'day',
		startBlockIndex: 0,
		blockCount: 4
	};

	const previews = getSectionExercisePreview(blocks, section, 2);
	assert.deepEqual(previews, ['Bench Press', 'Incline Dumbbell Press']);
});

test('formatRelativeDate returns friendly relative descriptions', () => {
	const today = new Date().toISOString();
	assert.equal(formatRelativeDate(today), 'Today');

	const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
	assert.equal(formatRelativeDate(yesterday), 'Yesterday');

	const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString();
	assert.equal(formatRelativeDate(threeDaysAgo), '3 days ago');
});
