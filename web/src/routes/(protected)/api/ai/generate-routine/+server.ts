import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { generateRoutineWithAi } from '$lib/server/ai';
import { parseAndValidateRoutineJson } from '$lib/editor/routineJson';
import { toWorkflowPayload } from '$lib/editor/types';
import { isDemoMode } from '$lib/server/demo/config';

export const POST: RequestHandler = async ({ request }) => {
	const clientApiKey =
		request.headers.get('x-ai-api-key') ||
		request.headers.get('x-gemini-api-key') ||
		request.headers.get('x-openai-api-key') ||
		undefined;

	let body: any = {};
	try {
		body = await request.json();
	} catch {
		body = {};
	}

	const hasServerKey = Boolean(
		process.env.GEMINI_API_KEY?.trim() || process.env.OPENAI_API_KEY?.trim()
	);

	if (isDemoMode() && !clientApiKey && !body.api_key && !hasServerKey) {
		const promptText = String(body.prompt || '').trim();
		const isHomeGym = /72|home|plate|cap|gzclp/i.test(promptText);
		const demoRoutine = {
			name: isHomeGym ? 'AI Home Gym GZCLP (Demo)' : 'AI Strength & Hypertrophy Split (Demo)',
			description: promptText
				? `Generated in Demo Showcase from prompt: "${promptText.slice(0, 120)}"`
				: 'Generated in Demo Showcase mode (connect a Gemini or OpenAI key in AI settings for live LLM generation).',
			sections: [
				{
					title: 'Day 1 - Primary Strength',
					blocks: [
						{
							type: 'linear_progression',
							exercise_name: 'Barbell Squat',
							sets: 5,
							reps: '3+',
							start_load: 65,
							load_unit: 'kg',
							increment: 2.5,
							max_load: isHomeGym ? 72 : null,
							on_max_load: isHomeGym ? 'expand_reps' : undefined,
							rest_seconds: 180
						},
						{
							type: 'exercise',
							exercise_name: 'Incline Dumbbell Press',
							sets: 3,
							reps: '8-12',
							load_value: 24,
							load_unit: 'kg',
							rest_seconds: 90,
							progression: { type: 'double', min_reps: 8, max_reps: 12, increment: 2 }
						}
					]
				}
			]
		};
		const parsed = parseAndValidateRoutineJson(JSON.stringify(demoRoutine));
		const blocks =
			parsed.success && parsed.draftBlocks ? toWorkflowPayload(parsed.draftBlocks) : [];

		return json({
			routine_name: demoRoutine.name,
			description: demoRoutine.description,
			days: demoRoutine.sections.map((s) => ({
				day_name: s.title,
				exercises: s.blocks.map((b: any) => ({
					name: b.exercise_name,
					sets: b.sets,
					reps: String(b.reps),
					target_load: Number(b.start_load ?? b.load_value ?? 0),
					rest_seconds: Number(b.rest_seconds || 90)
				}))
			})),
			blocks
		});
	}

	try {
		const result = await generateRoutineWithAi({
			prompt: body.prompt || '',
			goal: body.goal,
			split: body.split,
			level: body.level,
			equipment: body.equipment,
			constraints: body.constraints,
			apiKey: clientApiKey || body.api_key
		});

		// Defensive conversion into blocks
		const parsed = parseAndValidateRoutineJson(JSON.stringify(result));
		const blocks =
			parsed.success && parsed.draftBlocks ? toWorkflowPayload(parsed.draftBlocks) : [];

		return json({
			routine_name: result.name || result.routine_name || 'Generated Routine',
			description: result.description || '',
			days: (result.sections || result.days || []).map((s: any, idx: number) => ({
				day_name: s.title || s.day_name || `Day ${idx + 1}`,
				exercises: (s.blocks || s.exercises || [])
					.filter((b: any) => b.node_type_slug === 'exercise' || b.exercise_name || b.name)
					.map((b: any) => ({
						name: b.exercise_name || b.name || 'Exercise',
						sets: b.sets || 3,
						reps: String(b.reps || '8-10'),
						target_load: Number(b.load_value || b.target_load || 0),
						rest_seconds: Number(b.rest_seconds || 90)
					}))
			})),
			blocks
		});
	} catch (err: any) {
		return json({ error: err?.message || 'Failed to generate routine' }, { status: 500 });
	}
};
