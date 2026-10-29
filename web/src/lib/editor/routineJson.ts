import type { DraftBlock, Workflow, WorkflowBlockApi } from './types';

export type CanonicalProgressionJson = {
	type: 'none' | 'linear' | 'double' | 'rpe' | 'wave';
	increment?: number;
	rule?: string;
	min_reps?: number;
	max_reps?: number;
	target_rpe?: number;
	target_rir?: number;
	deload_percent?: number;
	notes?: string;
};

export type CanonicalBlockJson = {
	type?: string;
	node_type_slug?: string;
	exercise_name?: string;
	name?: string;
	sets?: number;
	reps?: string | number;
	target_load?: number | string | null;
	load_value?: number | string | null;
	start_load?: number | string | null;
	load_unit?: string;
	rest_seconds?: number;
	duration?: number;
	notes?: string;
	progression?: CanonicalProgressionJson;
	[key: string]: unknown;
};

export type CanonicalSectionJson = {
	title: string;
	subtitle?: string;
	kind?: string;
	blocks: CanonicalBlockJson[];
};

export type CanonicalRoutineJson = {
	$schema?: string;
	version: '1.0';
	name: string;
	description?: string;
	is_public?: boolean;
	tags?: string[];
	sections: CanonicalSectionJson[];
};

export type ParseRoutineResult = {
	success: boolean;
	data?: CanonicalRoutineJson;
	draftBlocks?: DraftBlock[];
	error?: string;
	summary?: {
		name: string;
		description: string;
		sectionsCount: number;
		exercisesCount: number;
		totalBlocksCount: number;
	};
};

function cryptoLikeRandom(): string {
	return Math.random().toString(36).slice(2, 10);
}

/**
 * Serializes a Workflow and its DraftBlocks into the canonical RepEngine Routine JSON v1 format.
 */
export function exportWorkflowToCanonicalJson(
	workflow: { name: string; description?: string; is_public?: boolean },
	blocks: DraftBlock[]
): CanonicalRoutineJson {
	const sections: CanonicalSectionJson[] = [];
	let currentSection: CanonicalSectionJson = {
		title: 'Main Workout',
		blocks: []
	};
	let hasEncounteredSection = false;

	for (const block of blocks) {
		if (block.node_type_slug === 'section') {
			if (hasEncounteredSection || currentSection.blocks.length > 0) {
				sections.push(currentSection);
			}
			hasEncounteredSection = true;
			currentSection = {
				title: (block.data.title as string) || `Day ${sections.length + 1}`,
				subtitle: (block.data.subtitle as string) || undefined,
				kind: (block.data.kind as string) || 'day',
				blocks: []
			};
		} else {
			const bData = block.data || {};
			const blockJson: CanonicalBlockJson = {
				type: block.node_type_slug,
				node_type_slug: block.node_type_slug,
				...bData
			};

			// Normalize exercise name
			if (bData.exercise_name) {
				blockJson.exercise_name = bData.exercise_name as string;
			}

			if (block.node_type_slug === 'exercise') {
				if (bData.load_value !== undefined && bData.load_value !== null) {
					blockJson.target_load = bData.load_value as number;
				}
				delete (blockJson as Record<string, any>).load_value;
				delete (blockJson as Record<string, any>).load;
				delete (blockJson as Record<string, any>).start_load;
			} else if (block.node_type_slug === 'linear_progression') {
				if (bData.start_load !== undefined && bData.start_load !== null) {
					blockJson.target_load = bData.start_load as number;
				}
				delete (blockJson as Record<string, any>).start_load;
				delete (blockJson as Record<string, any>).load_value;
				delete (blockJson as Record<string, any>).load;
			} else if (block.node_type_slug === 'superset') {
				delete (blockJson as Record<string, any>).load_value_a;
				delete (blockJson as Record<string, any>).load_value_b;
				delete (blockJson as Record<string, any>).load_a;
				delete (blockJson as Record<string, any>).load_b;
				delete (blockJson as Record<string, any>).target_load;
			}

			// Normalize progression
			if (bData.progression && typeof bData.progression === 'object') {
				const prog = { ...(bData.progression as CanonicalProgressionJson) };
				if (prog.type === 'double' && (!prog.min_reps || !prog.max_reps)) {
					const rangeMatch = String(bData.reps || '').match(/(\d+)\s*[-–]\s*(\d+)/);
					if (rangeMatch) {
						prog.min_reps = Number(rangeMatch[1]);
						prog.max_reps = Number(rangeMatch[2]);
					}
				}
				blockJson.progression = prog;
			} else if (block.node_type_slug === 'linear_progression') {
				blockJson.progression = {
					type: 'linear',
					increment: typeof bData.increment === 'number' ? bData.increment : 2.5,
					rule: (bData.progression_rule as string) || 'add_each_session',
					notes: (bData.notes as string) || undefined
				};
			}

			currentSection.blocks.push(blockJson);
		}
	}

	if (hasEncounteredSection || currentSection.blocks.length > 0) {
		sections.push(currentSection);
	}

	return {
		$schema: 'https://repengine.app/schemas/routine-v1.json',
		version: '1.0',
		name: workflow.name || 'Untitled Routine',
		description: workflow.description || '',
		is_public: workflow.is_public ?? false,
		sections
	};
}

/**
 * Defensively parses and validates arbitrary JSON (canonical or flat),
 * returning normalized CanonicalRoutineJson and ready-to-use DraftBlocks.
 */
export function parseAndValidateRoutineJson(jsonInput: string): ParseRoutineResult {
	if (!jsonInput || !jsonInput.trim()) {
		return { success: false, error: 'JSON content is empty.' };
	}

	let parsed: any;
	try {
		parsed = JSON.parse(jsonInput.trim());
	} catch (e: any) {
		return { success: false, error: `Invalid JSON syntax: ${e?.message || 'Parse error'}` };
	}

	if (!parsed || typeof parsed !== 'object') {
		return { success: false, error: 'JSON root must be an object or list.' };
	}

	let routineName = 'Imported Routine';
	let routineDescription = '';
	let sections: CanonicalSectionJson[] = [];

	if (Array.isArray(parsed)) {
		// Array of blocks
		sections = [
			{
				title: 'Workout Day',
				blocks: parsed
			}
		];
	} else {
		routineName = parsed.name || parsed.title || parsed.routine_name || 'Imported Routine';
		routineDescription = parsed.description || parsed.notes || '';

		if (Array.isArray(parsed.sections)) {
			// Canonical format with sections
			sections = parsed.sections.map((s: any, idx: number) => ({
				title: s.title || `Day ${idx + 1}`,
				subtitle: s.subtitle || '',
				kind: s.kind || 'day',
				blocks: Array.isArray(s.blocks) ? s.blocks : Array.isArray(s.exercises) ? s.exercises : []
			}));
		} else if (Array.isArray(parsed.days)) {
			// Genkit / AI output format with days
			sections = parsed.days.map((d: any, idx: number) => ({
				title: d.title || d.day || `Day ${idx + 1}`,
				subtitle: d.focus || d.subtitle || '',
				kind: 'day',
				blocks: Array.isArray(d.exercises) ? d.exercises : Array.isArray(d.blocks) ? d.blocks : []
			}));
		} else if (Array.isArray(parsed.blocks)) {
			// Flat blocks format
			let currentSec: CanonicalSectionJson = { title: 'Day 1', blocks: [] };
			for (const b of parsed.blocks) {
				const slug = b.node_type_slug || b.type;
				if (slug === 'section') {
					if (currentSec.blocks.length > 0) sections.push(currentSec);
					currentSec = {
						title: b.data?.title || b.title || 'Day',
						subtitle: b.data?.subtitle || b.subtitle || '',
						kind: 'day',
						blocks: []
					};
				} else {
					currentSec.blocks.push(b);
				}
			}
			sections.push(currentSec);
		} else {
			return {
				success: false,
				error: 'JSON must contain either a "sections", "days", or "blocks" array.'
			};
		}
	}

	// Transform into DraftBlocks for the RepEngine editor & database
	const draftBlocks: DraftBlock[] = [];
	let position = 0;
	let exerciseCount = 0;

	for (const section of sections) {
		// Insert section block
		draftBlocks.push({
			client_id: `sec-${position}-${cryptoLikeRandom()}`,
			node_type_slug: 'section',
			position: position++,
			data: {
				title: section.title,
				subtitle: section.subtitle || '',
				kind: section.kind || 'day',
				collapsed: false
			}
		});

		for (const rawItem of section.blocks) {
			const rawBlock = rawItem as Record<string, any>;
			const rawBlockData = (rawBlock.data && typeof rawBlock.data === 'object') ? rawBlock.data : null;
			let slug = String(rawBlock.node_type_slug || rawBlock.type || 'exercise');

			// Check if linear progression is configured
			const prog = (rawBlock.progression && typeof rawBlock.progression === 'object')
				? rawBlock.progression
				: (rawBlockData?.progression && typeof rawBlockData.progression === 'object')
					? rawBlockData.progression
					: null;

			if (slug === 'linear_progression' || (slug === 'exercise' && prog?.type === 'linear')) {
				slug = 'linear_progression';
			}

			const exerciseName =
				rawBlock.exercise_name ||
				rawBlock.name ||
				(rawBlockData && typeof rawBlockData.exercise_name === 'string' ? rawBlockData.exercise_name : '') ||
				'Exercise';

			const rawLoad = rawBlock.target_load ?? rawBlock.load_value ?? rawBlock.start_load ?? rawBlockData?.load_value ?? rawBlockData?.start_load ?? rawBlockData?.target_load;
			const loadNum = (rawLoad !== undefined && rawLoad !== null && rawLoad !== '') ? Number(rawLoad) : null;
			const loadUnit = String(rawBlock.load_unit || rawBlockData?.load_unit || 'kg');
			const sets = Number(rawBlock.sets || rawBlockData?.sets || 3);
			const reps = String(rawBlock.reps || rawBlockData?.reps || '5');
			const restSeconds = Number(rawBlock.rest_seconds || rawBlockData?.rest_seconds || 90);
			const notes = String(rawBlock.notes || rawBlockData?.notes || '');

			let cleanData: Record<string, any> = {};

			if (slug === 'linear_progression') {
				exerciseCount++;
				const increment = Number(prog?.increment ?? rawBlock.increment ?? rawBlockData?.increment ?? 2.5);
				const rule = String(prog?.rule ?? rawBlock.progression_rule ?? rawBlockData?.progression_rule ?? 'add_each_session');
				const deloadPercent = (prog?.deload_percent ?? rawBlock.deload_percent ?? rawBlockData?.deload_percent);

				cleanData = {
					exercise_name: exerciseName,
					sets,
					reps,
					start_load: loadNum,
					load_unit: loadUnit,
					increment,
					progression_rule: rule,
					rest_seconds: restSeconds,
					notes
				};
				if (deloadPercent !== undefined && deloadPercent !== null) {
					cleanData.deload_percent = Number(deloadPercent);
				}
			} else if (slug === 'exercise') {
				exerciseCount++;
				cleanData = {
					exercise_name: exerciseName,
					sets,
					reps,
					load_value: loadNum,
					load_unit: loadUnit,
					rest_seconds: restSeconds,
					notes
				};
				if (prog && prog.type !== 'none') {
					if (prog.type === 'double') {
						if (!prog.min_reps || !prog.max_reps) {
							const rangeMatch = String(reps).match(/(\d+)\s*[-–]\s*(\d+)/);
							if (rangeMatch) {
								prog.min_reps = Number(rangeMatch[1]);
								prog.max_reps = Number(rangeMatch[2]);
							}
						}
					}
					cleanData.progression = prog;
				}
			} else if (slug === 'rest') {
				const duration = Number(rawBlock.duration || rawBlock.seconds || rawBlock.rest_seconds || rawBlockData?.duration || 60);
				cleanData = { duration };
			} else if (slug === 'exercise_timed') {
				exerciseCount++;
				const duration = Number(rawBlock.duration || rawBlockData?.duration || 30);
				cleanData = {
					exercise_name: exerciseName,
					duration
				};
			} else if (slug === 'superset') {
				exerciseCount += 2;
				const startLoadA =
					rawBlock.start_load_a ??
					rawBlock.load_value_a ??
					rawBlock.load_a ??
					rawBlock.target_load_a ??
					rawBlockData?.start_load_a ??
					rawBlockData?.load_value_a ??
					null;
				const startLoadB =
					rawBlock.start_load_b ??
					rawBlock.load_value_b ??
					rawBlock.load_b ??
					rawBlock.target_load_b ??
					rawBlockData?.start_load_b ??
					rawBlockData?.load_value_b ??
					null;

				cleanData = {
					exercise_a_name: rawBlock.exercise_a_name ?? rawBlockData?.exercise_a_name ?? '',
					exercise_b_name: rawBlock.exercise_b_name ?? rawBlockData?.exercise_b_name ?? '',
					sets: Number(rawBlock.sets || rawBlockData?.sets || 3),
					reps_a: String(rawBlock.reps_a ?? rawBlockData?.reps_a ?? '5-8'),
					reps_b: String(rawBlock.reps_b ?? rawBlockData?.reps_b ?? '5-8'),
					progression_type_a: String(rawBlock.progression_type_a ?? rawBlockData?.progression_type_a ?? 'none'),
					progression_type_b: String(rawBlock.progression_type_b ?? rawBlockData?.progression_type_b ?? 'none'),
					start_load_a: startLoadA !== null && startLoadA !== '' ? Number(startLoadA) : null,
					start_load_b: startLoadB !== null && startLoadB !== '' ? Number(startLoadB) : null,
					increment_a: Number(rawBlock.increment_a ?? rawBlockData?.increment_a ?? 2.5),
					increment_b: Number(rawBlock.increment_b ?? rawBlockData?.increment_b ?? 2.5),
					load_unit_a: String(rawBlock.load_unit_a ?? rawBlockData?.load_unit_a ?? 'kg'),
					load_unit_b: String(rawBlock.load_unit_b ?? rawBlockData?.load_unit_b ?? 'kg'),
					min_reps_a: Number(rawBlock.min_reps_a ?? rawBlockData?.min_reps_a ?? 5),
					max_reps_a: Number(rawBlock.max_reps_a ?? rawBlockData?.max_reps_a ?? 8),
					min_reps_b: Number(rawBlock.min_reps_b ?? rawBlockData?.min_reps_b ?? 5),
					max_reps_b: Number(rawBlock.max_reps_b ?? rawBlockData?.max_reps_b ?? 8),
					progression_rule_a: String(rawBlock.progression_rule_a ?? rawBlockData?.progression_rule_a ?? 'add_each_session'),
					progression_rule_b: String(rawBlock.progression_rule_b ?? rawBlockData?.progression_rule_b ?? 'add_each_session'),
					rest_seconds: Number(rawBlock.rest_seconds ?? rawBlockData?.rest_seconds ?? 120),
					notes: String(rawBlock.notes ?? rawBlockData?.notes ?? '')
				};
			} else {
				cleanData = { ...(rawBlockData || rawBlock) };
				delete cleanData.type;
				delete cleanData.node_type_slug;
				delete cleanData.target_load;
				delete cleanData.start_load;
			}

			draftBlocks.push({
				client_id: `blk-${position}-${cryptoLikeRandom()}`,
				node_type_slug: slug,
				position: position++,
				data: cleanData
			});
		}
	}

	const canonical: CanonicalRoutineJson = {
		$schema: 'https://repengine.app/schemas/routine-v1.json',
		version: '1.0',
		name: routineName,
		description: routineDescription,
		sections
	};

	return {
		success: true,
		data: canonical,
		draftBlocks,
		summary: {
			name: routineName,
			description: routineDescription,
			sectionsCount: sections.length,
			exercisesCount: exerciseCount,
			totalBlocksCount: draftBlocks.length
		}
	};
}

/**
 * Returns a high-quality copy-paste prompt template for external LLMs (ChatGPT, Claude, Gemini)
 * instructed to output JSON strictly matching the RepEngine schema.
 */
export function generateAiPromptTemplate(): string {
	return `You are an elite strength & conditioning coach and sports scientist.
Generate a structured workout routine strictly matching the RepEngine JSON schema below.

MANDATORY RULES:
1. Return ONLY the raw valid JSON code block (no markdown explanations before or after).
2. Organize the routine into days/sections using the "sections" array.
3. For each exercise, provide "sets", "reps", "target_load" (if applicable), "rest_seconds", and "progression".
4. "progression.type" can be:
   - "linear": adds weight each session (e.g. +2.5 kg).
   - "double": keeps weight fixed and progresses reps from min_reps to max_reps before increasing weight.
   - "rpe": autoregulated target effort based on RPE or RIR.
   - "none": fixed load without automatic progression.

VALID SCHEMA EXAMPLE:
{
  "$schema": "https://repengine.app/schemas/routine-v1.json",
  "version": "1.0",
  "name": "Upper / Lower Strength & Hypertrophy",
  "description": "4-day periodized upper/lower split focusing on compound progression and hypertrophy.",
  "sections": [
    {
      "title": "Day 1 - Upper Power",
      "subtitle": "Chest, Back, Shoulders & Arms",
      "blocks": [
        {
          "type": "exercise",
          "exercise_name": "Barbell Bench Press",
          "sets": 3,
          "reps": "5",
          "target_load": 80,
          "load_unit": "kg",
          "rest_seconds": 180,
          "notes": "1-second pause on chest. RIR 2.",
          "progression": {
            "type": "linear",
            "increment": 2.5,
            "rule": "add_each_session"
          }
        },
        {
          "type": "exercise",
          "exercise_name": "Dumbbell Overhead Press",
          "sets": 3,
          "reps": "8-12",
          "target_load": 24,
          "load_unit": "kg",
          "rest_seconds": 120,
          "progression": {
            "type": "double",
            "min_reps": 8,
            "max_reps": 12,
            "increment": 2
          }
        },
        {
          "type": "rest",
          "duration": 90
        }
      ]
    }
  ]
}

Desired parameters for my routine:
- Goal: [Hypertrophy / Strength / Calisthenics / Powerbuilding]
- Weekly Split: [e.g. Upper / Lower 4 days, PPL 6 days, Full Body 3 days]
- Experience Level: [Beginner / Intermediate / Advanced]
- Equipment Available: [Commercial gym / Barbell & Dumbbells / Bodyweight only]
- Constraints / Injuries: [e.g. Avoid barbell back squats due to lower back discomfort]
`;
}
