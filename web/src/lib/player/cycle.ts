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
		lastIdx = playableSections.findIndex((s) => s.id === lastCompleted.section_id);
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
