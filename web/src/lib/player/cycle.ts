import type { PlayerBlock, PlayerSection } from '$lib/player/types';
import type { WorkoutSession } from '$lib/workout-sessions/types';

export interface CycleInfo {
	nextSection: PlayerSection | null;
	lastCompletedSection: PlayerSection | null;
	lastCompletedSession: WorkoutSession | null;
	nextIndex: number;
	lastIndex: number;
}

/**
 * Calculates the next section in the routine cycle based on previous completed sessions.
 */
export function getNextAndLastCompletedSection(
	sections: PlayerSection[] | undefined | null,
	sessionHistory: WorkoutSession[] | undefined | null
): CycleInfo {
	const playableSections = sections ?? [];
	if (playableSections.length === 0) {
		return {
			nextSection: null,
			lastCompletedSection: null,
			lastCompletedSession: null,
			nextIndex: 0,
			lastIndex: -1
		};
	}

	const history = sessionHistory ?? [];
	const lastCompleted = history.find(
		(s) => s.status === 'completed' && (Boolean(s.section_id) || Boolean(s.section_title))
	);

	if (!lastCompleted) {
		return {
			nextSection: playableSections[0],
			lastCompletedSection: null,
			lastCompletedSession: null,
			nextIndex: 0,
			lastIndex: -1
		};
	}

	let lastIdx = -1;
	if (lastCompleted.section_id) {
		lastIdx = playableSections.findIndex((s) => String(s.id) === String(lastCompleted.section_id));
	}
	if (lastIdx === -1 && lastCompleted.section_title) {
		const targetTitle = lastCompleted.section_title.trim().toLowerCase();
		lastIdx = playableSections.findIndex((s) => s.title.trim().toLowerCase() === targetTitle);
	}

	if (lastIdx === -1) {
		return {
			nextSection: playableSections[0],
			lastCompletedSection: null,
			lastCompletedSession: lastCompleted,
			nextIndex: 0,
			lastIndex: -1
		};
	}

	const nextIdx = (lastIdx + 1) % playableSections.length;
	return {
		nextSection: playableSections[nextIdx],
		lastCompletedSection: playableSections[lastIdx],
		lastCompletedSession: lastCompleted,
		nextIndex: nextIdx,
		lastIndex: lastIdx
	};
}

/**
 * Extracts preview exercise titles for a section, skipping rests or sections.
 */
export function getSectionExercisePreview(
	blocks: PlayerBlock[] | undefined | null,
	section: PlayerSection,
	max = 3
): string[] {
	if (!blocks || blocks.length === 0) return [];
	const sectionBlocks = blocks.slice(
		section.startBlockIndex,
		section.startBlockIndex + section.blockCount
	);

	const titles: string[] = [];
	for (const block of sectionBlocks) {
		if (block.node_type_slug === 'rest' || block.node_type_slug === 'section') continue;
		if (block.title && !titles.includes(block.title)) {
			titles.push(block.title);
			if (titles.length >= max) break;
		}
	}
	return titles;
}

/**
 * Formats an ISO date relative to current time (e.g., 'Today', 'Yesterday', '3 days ago').
 */
export function formatRelativeDate(isoString: string | null | undefined): string {
	if (!isoString) return '';
	const date = new Date(isoString);
	if (Number.isNaN(date.getTime())) return '';

	const now = new Date();
	const diffMs = now.getTime() - date.getTime();
	const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

	if (diffDays <= 0) return 'Today';
	if (diffDays === 1) return 'Yesterday';
	if (diffDays < 7) return `${diffDays} days ago`;

	return date.toLocaleDateString([], {
		day: '2-digit',
		month: 'short'
	});
}

export interface SectionProgressionSummary {
	title: string;
	exerciseName: string;
	stateType: 'linear' | 'wave' | 'skill';
	outcome: string;
	currentLoad: string;
	suggestedLoad: string;
	suggestedWeek?: number;
	summary?: string;
}

/**
 * Finds the most recent completed session for a specific routine section.
 */
export function getLastCompletedSessionForSection(
	section: PlayerSection,
	sessionHistory: WorkoutSession[] | undefined | null
): WorkoutSession | null {
	if (!sessionHistory || sessionHistory.length === 0) return null;
	const targetTitle = section.title.trim().toLowerCase();
	return (
		sessionHistory.find(
			(s) =>
				s.status === 'completed' &&
				(String(s.section_id) === String(section.id) || (Boolean(s.section_title) && s.section_title.trim().toLowerCase() === targetTitle))
		) ?? null
	);
}

/**
 * Extracts progression state summaries (loads, scheme, progression status) for blocks in a given section.
 */
export function getSectionProgressionSummaries(
	blocks: PlayerBlock[] | undefined | null,
	section: PlayerSection,
	progressionStates: Array<{
		workflow_block_id?: number;
		exercise_name?: string;
		state_type?: 'linear' | 'wave' | 'skill';
		outcome?: string;
		current_load?: string;
		suggested_load?: string;
		suggested_week?: number;
		summary?: string;
	}> | undefined | null
): SectionProgressionSummary[] {
	if (!blocks || blocks.length === 0) return [];
	const sectionBlocks = blocks.slice(
		section.startBlockIndex,
		section.startBlockIndex + section.blockCount
	);

	type ProgressionItem = NonNullable<typeof progressionStates>[number];
	const stateByBlockID = new Map<number, ProgressionItem>();
	if (progressionStates && progressionStates.length > 0) {
		for (const state of progressionStates) {
			if (state.workflow_block_id) {
				stateByBlockID.set(state.workflow_block_id, state);
			}
		}
	}

	const summaries: SectionProgressionSummary[] = [];
	for (const block of sectionBlocks) {
		const blockExercise = (typeof block.data?.exercise_name === 'string' ? block.data.exercise_name : null) || block.title;
		if (block.workflowBlockID && stateByBlockID.has(block.workflowBlockID)) {
			const state = stateByBlockID.get(block.workflowBlockID)!;
			summaries.push({
				title: block.title,
				exerciseName: state.exercise_name || blockExercise,
				stateType: state.state_type || 'linear',
				outcome: state.outcome || 'maintain',
				currentLoad: state.current_load || '',
				suggestedLoad: state.suggested_load || '',
				suggestedWeek: state.suggested_week,
				summary: state.summary
			});
		} else if (block.node_type_slug === 'linear_progression' && (block.load || block.increment)) {
			const blockLoad = block.load ? `${block.load} ${block.loadUnit || 'kg'}` : 'BW';
			summaries.push({
				title: block.title,
				exerciseName: blockExercise,
				stateType: 'linear',
				outcome: 'increase',
				currentLoad: blockLoad,
				suggestedLoad: blockLoad
			});
		}
	}

	return summaries;
}
