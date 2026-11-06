import type { AiGenerateInput, AiModelOption, AiParseInput } from './types';

// Strict schema for Google Gemini Structured Output
const ROUTINE_SCHEMA = {
	type: 'OBJECT',
	properties: {
		name: { type: 'STRING', description: 'Workout routine name' },
		description: { type: 'STRING', description: 'Brief summary of routine focus' },
		sections: {
			type: 'ARRAY',
			description: 'Routine days/sections (e.g. Day 1, Workout A, etc.)',
			items: {
				type: 'OBJECT',
				properties: {
					title: { type: 'STRING', description: 'Day/Section name (e.g. Day 1 - Push)' },
					subtitle: { type: 'STRING', description: 'Target muscle groups' },
					kind: { type: 'STRING', enum: ['day', 'warmup', 'cooldown'] },
					blocks: {
						type: 'ARRAY',
						items: {
							type: 'OBJECT',
							properties: {
								node_type_slug: {
									type: 'STRING',
									enum: ['exercise', 'superset', 'exercise_timed', 'rest']
								},
								exercise_name: { type: 'STRING' },
								sets: { type: 'INTEGER' },
								reps: { type: 'STRING' },
								load_value: { type: 'NUMBER' },
								load_unit: { type: 'STRING', enum: ['kg', 'lbs'] },
								rest_seconds: { type: 'INTEGER' },
								notes: { type: 'STRING' },
								exercise_a_name: { type: 'STRING' },
								exercise_b_name: { type: 'STRING' },
								reps_a: { type: 'STRING' },
								reps_b: { type: 'STRING' },
								start_load_a: { type: 'NUMBER' },
								start_load_b: { type: 'NUMBER' },
								duration: { type: 'INTEGER' }
							},
							required: ['node_type_slug']
						}
					}
				},
				required: ['title', 'blocks']
			}
		}
	},
	required: ['name', 'sections']
};

export async function parseRoutineWithGemini(input: AiParseInput): Promise<any> {
	const effectiveApiKey = input.apiKey?.trim() || process.env.GEMINI_API_KEY?.trim();

	if (!effectiveApiKey) {
		throw new Error(
			'Gemini API key not configured. Provide a key in the x-gemini-api-key header or set GEMINI_API_KEY in .env.'
		);
	}

	const parts: Array<Record<string, unknown>> = [];

	if (input.imageBytesBase64) {
		const rawMime = input.mimeType?.toLowerCase().trim();
		const safeMime = rawMime && rawMime.startsWith('image/') ? rawMime : 'image/jpeg';
		parts.push({
			inlineData: {
				mimeType: safeMime,
				data: input.imageBytesBase64
			}
		});
	}

	const promptText = `
You are an expert strength and conditioning specialist and sports scientist.
Your mission is to extract or convert the provided routine information (whether a gym routine photo, handwritten notes, or free text) into the formal RepEngine workout structure.

Key rules:
1. Identify routine days (e.g. Day 1, Workout A, Push Day, etc.) and map them to "sections".
2. For each exercise:
   - If conventional exercise, use node_type_slug: "exercise" with "sets", "reps", "load_value" (if load is specified, otherwise 0) and "rest_seconds" (default 90 if omitted).
   - If superset (two exercises paired back-to-back), use node_type_slug: "superset" populating exercise_a_name and exercise_b_name.
   - If cardio or timed plank/hold, use node_type_slug: "exercise_timed" with "duration" in seconds.
3. Standardize exercise names into clean, recognized English terms.
4. Return strictly the JSON object matching the provided schema.
${input.text?.trim() ? `\nUser provided text:\n${input.text.trim()}` : ''}
`;

	parts.push({ text: promptText });

	return callGemini(effectiveApiKey, parts, ROUTINE_SCHEMA, input.model);
}

export async function generateRoutineWithGemini(input: AiGenerateInput): Promise<any> {
	const effectiveApiKey = input.apiKey?.trim() || process.env.GEMINI_API_KEY?.trim();

	if (!effectiveApiKey) {
		throw new Error(
			'Gemini API key not configured. Provide a key in the x-gemini-api-key header or set GEMINI_API_KEY in .env.'
		);
	}

	const prompt = `
You are an elite strength and conditioning coach and sports scientist. Create a structured, periodized workout routine based on the following preferences:
- Primary goal: ${input.goal || 'Hypertrophy'}
- Routine split: ${input.split || 'Full Body'}
- Athlete level: ${input.level || 'Intermediate'}
- Available equipment: ${input.equipment || 'Full Commercial Gym'}
- Constraints / Notes: ${input.constraints || 'None'}
- User specific request: "${input.prompt}"

Rules:
1. Structure the routine into organized days (sections).
2. For each exercise, specify sets, reps, estimated starting load in kg (load_value), and rest in seconds (rest_seconds).
3. Use clean, standardized English exercise names.
`;

	return callGemini(effectiveApiKey, [{ text: prompt }], ROUTINE_SCHEMA, input.model);
}

const DEFAULT_CANDIDATE_MODELS = [
	'gemini-2.5-flash',
	'gemini-2.0-flash',
	'gemini-2.5-flash-lite',
	'gemini-2.0-flash-lite',
	'gemini-2.5-pro'
];

export async function resolveGeminiModels(apiKey: string): Promise<string[]> {
	const customModel = process.env.GEMINI_MODEL?.trim();
	if (customModel) {
		return [customModel, ...DEFAULT_CANDIDATE_MODELS.filter((m) => m !== customModel)];
	}

	try {
		const url = new URL('https://generativelanguage.googleapis.com/v1beta/models');
		url.searchParams.set('key', apiKey);
		const res = await fetch(url.toString(), {
			method: 'GET',
			headers: { 'Content-Type': 'application/json' },
			signal: AbortSignal.timeout(3500)
		});

		if (res.ok) {
			const data: any = await res.json();
			if (Array.isArray(data?.models)) {
				const available: string[] = data.models
					.filter(
						(m: any) =>
							Array.isArray(m?.supportedGenerationMethods) &&
							m.supportedGenerationMethods.includes('generateContent')
					)
					.map((m: any) => (m.name || '').replace(/^models\//, ''))
					.filter(
						(name: string) =>
							Boolean(name) &&
							!name.includes('embedding') &&
							!name.includes('aqa') &&
							!name.includes('tts') &&
							!name.includes('imagen') &&
							!name.startsWith('gemini-1.0') &&
							!name.startsWith('gemini-1.5')
					);

				// Prioritize Flash models (2.5 > 3.x > 2.0), then Pro models
				const sorted = available.sort((a: string, b: string) => {
					const score = (m: string) => {
						let s = 0;
						if (m.includes('flash')) s += 100;
						if (m.includes('2.5')) s += 50;
						else if (m.includes('3.')) s += 40;
						else if (m.includes('2.0')) s += 30;
						if (m.includes('lite')) s -= 5;
						return s;
					};
					return score(b) - score(a);
				});

				if (sorted.length > 0) {
					return Array.from(new Set([...sorted, ...DEFAULT_CANDIDATE_MODELS]));
				}
			}
		}
	} catch {
		// Ignore discovery errors and fall back to defaults
	}

	return DEFAULT_CANDIDATE_MODELS;
}

export async function listGeminiModels(apiKey: string): Promise<AiModelOption[]> {
	const modelIds = await resolveGeminiModels(apiKey);
	return modelIds.map((id) => {
		let name = id;
		if (id === 'gemini-2.5-flash') name = 'Gemini 2.5 Flash (Recommended Default)';
		else if (id === 'gemini-2.0-flash') name = 'Gemini 2.0 Flash';
		else if (id === 'gemini-2.5-flash-lite') name = 'Gemini 2.5 Flash Lite (Faster)';
		else if (id === 'gemini-2.0-flash-lite') name = 'Gemini 2.0 Flash Lite';
		else if (id === 'gemini-2.5-pro') name = 'Gemini 2.5 Pro (Advanced Reasoning)';
		else {
			name = id
				.replace(/-/g, ' ')
				.replace(/\b\w/g, (c) => c.toUpperCase());
		}

		return {
			id,
			name,
			provider: 'gemini',
			isVision: true
		};
	});
}

async function callGemini(
	apiKey: string,
	parts: Array<Record<string, unknown>>,
	schema: Record<string, unknown>,
	explicitModel?: string
): Promise<any> {
	let candidateModels = await resolveGeminiModels(apiKey);
	if (explicitModel?.trim()) {
		candidateModels = [explicitModel.trim(), ...candidateModels.filter((m) => m !== explicitModel.trim())];
	}

	let lastError: Error | null = null;

	for (const model of candidateModels) {
		const url = new URL(
			`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`
		);
		url.searchParams.set('key', apiKey);

		// First try with structured responseSchema
		let response = await fetch(url, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				contents: [{ parts }],
				generationConfig: {
					responseMimeType: 'application/json',
					responseSchema: schema,
					temperature: 0.1
				}
			})
		});

		// If 400 error possibly caused by strict schema validation, retry without responseSchema (plain JSON mode)
		if (!response.ok && response.status === 400) {
			const errorData: unknown = await response.clone().json().catch(() => null);
			const apiMessage =
				typeof errorData === 'object' &&
				errorData !== null &&
				'error' in errorData &&
				typeof errorData.error === 'object' &&
				errorData.error !== null &&
				'message' in errorData.error &&
				typeof errorData.error.message === 'string'
					? errorData.error.message
					: '';

			const msgLower = apiMessage.toLowerCase();
			if (
				msgLower.includes('responseschema') ||
				msgLower.includes('schema') ||
				msgLower.includes('invalid argument')
			) {
				const fallbackResponse = await fetch(url, {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						contents: [{ parts }],
						generationConfig: {
							responseMimeType: 'application/json',
							temperature: 0.1
						}
					})
				});
				if (fallbackResponse.ok) {
					response = fallbackResponse;
				}
			}
		}

		if (!response.ok) {
			const errorData: unknown = await response.json().catch(() => null);
			const apiMessage =
				typeof errorData === 'object' &&
				errorData !== null &&
				'error' in errorData &&
				typeof errorData.error === 'object' &&
				errorData.error !== null &&
				'message' in errorData.error &&
				typeof errorData.error.message === 'string'
					? errorData.error.message
					: null;

			const msgLower = (apiMessage || '').toLowerCase();

			// If key is invalid or quota exceeded, fail fast with a friendly message
			if (msgLower.includes('api key not valid') || msgLower.includes('invalid api key') || (response.status === 400 && msgLower.includes('api key'))) {
				throw new Error('Invalid Gemini API key. Please check your key in the BYOK field.');
			}
			if (response.status === 429 || msgLower.includes('quota') || msgLower.includes('resource exhausted')) {
				throw new Error('Rate limit exceeded on your Gemini key (Quota Exceeded). Please wait a moment or use another key.');
			}

			// Check if error is related to model availability or unsupported version, so we try the next candidate
			const isModelError =
				response.status === 404 ||
				(response.status === 400 &&
					(msgLower.includes('not found') ||
						msgLower.includes('not supported') ||
						msgLower.includes('deprecated') ||
						msgLower.includes('invalid argument') ||
						msgLower.includes('model')));

			if (isModelError) {
				lastError = new Error(apiMessage || `Model ${model} unavailable (HTTP ${response.status})`);
				continue;
			}

			throw new Error(apiMessage || `Gemini API error (HTTP ${response.status})`);
		}

		const result: unknown = await response.json();
		const rawJsonText =
			typeof result === 'object' &&
			result !== null &&
			'candidates' in result &&
			Array.isArray(result.candidates) &&
			result.candidates[0] &&
			typeof result.candidates[0] === 'object' &&
			'content' in result.candidates[0] &&
			result.candidates[0].content &&
			typeof result.candidates[0].content === 'object' &&
			'parts' in result.candidates[0].content &&
			Array.isArray(result.candidates[0].content.parts) &&
			result.candidates[0].content.parts[0] &&
			typeof result.candidates[0].content.parts[0] === 'object' &&
			'text' in result.candidates[0].content.parts[0] &&
			typeof result.candidates[0].content.parts[0].text === 'string'
				? result.candidates[0].content.parts[0].text
				: null;

		if (!rawJsonText?.trim()) {
			throw new Error('AI returned no valid content.');
		}

		let cleanJsonText = rawJsonText.trim();
		if (cleanJsonText.startsWith('```json')) {
			cleanJsonText = cleanJsonText.replace(/^```json\s*/, '').replace(/```\s*$/, '').trim();
		} else if (cleanJsonText.startsWith('```')) {
			cleanJsonText = cleanJsonText.replace(/^```\s*/, '').replace(/```\s*$/, '').trim();
		}

		try {
			return JSON.parse(cleanJsonText);
		} catch {
			throw new Error('AI returned a format that could not be parsed as valid JSON.');
		}
	}

	throw lastError || new Error('No compatible Gemini model could respond.');
}
