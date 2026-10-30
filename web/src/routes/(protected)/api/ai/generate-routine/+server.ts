import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { generateRoutineWithAi } from '$lib/server/ai';
import { parseAndValidateRoutineJson } from '$lib/editor/routineJson';
import { toWorkflowPayload } from '$lib/editor/types';

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
			routine_name: result.name || result.routine_name || 'Rotina Gerada',
			description: result.description || '',
			days: (result.sections || result.days || []).map((s: any, idx: number) => ({
				day_name: s.title || s.day_name || `Dia ${idx + 1}`,
				exercises: (s.blocks || s.exercises || [])
					.filter((b: any) => b.node_type_slug === 'exercise' || b.exercise_name || b.name)
					.map((b: any) => ({
						name: b.exercise_name || b.name || 'Exercício',
						sets: b.sets || 3,
						reps: String(b.reps || '8-10'),
						target_load: Number(b.load_value || b.target_load || 0),
						rest_seconds: Number(b.rest_seconds || 90)
					}))
			})),
			blocks
		});
	} catch (err: any) {
		return json({ error: err?.message || 'Falha na geração de rotina' }, { status: 500 });
	}
};
