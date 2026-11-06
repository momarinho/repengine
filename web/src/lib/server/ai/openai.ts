import type { AiGenerateInput, AiModelOption, AiParseInput } from './types';

const OPENAI_SCHEMA_PROMPT = `
You must respond STRICTLY with a valid JSON object, without any explanatory text before or after.
The JSON must strictly follow the schema structure below:
{
  "name": "Routine Name",
  "description": "Brief routine description",
  "sections": [
    {
      "title": "Day 1 - Push",
      "subtitle": "Chest, Shoulders & Triceps",
      "kind": "day",
      "blocks": [
        {
          "node_type_slug": "exercise",
          "exercise_name": "Barbell Bench Press",
          "sets": 3,
          "reps": "8-12",
          "load_value": 60,
          "load_unit": "kg",
          "rest_seconds": 90,
          "notes": ""
        },
        {
          "node_type_slug": "superset",
          "exercise_a_name": "Pull-Up",
          "exercise_b_name": "Dips",
          "sets": 3,
          "reps_a": "6-8",
          "reps_b": "8-10",
          "start_load_a": 0,
          "start_load_b": 0,
          "rest_seconds": 90
        },
        {
          "node_type_slug": "exercise_timed",
          "exercise_name": "Plank",
          "duration": 60
        },
        {
          "node_type_slug": "rest",
          "duration": 90
        }
      ]
    }
  ]
}
`;

export async function parseRoutineWithOpenAI(input: AiParseInput): Promise<any> {
	const effectiveApiKey = input.apiKey?.trim() || process.env.OPENAI_API_KEY?.trim();

	if (!effectiveApiKey) {
		throw new Error(
			'OpenAI API key not configured. Provide an sk-... key in the x-gemini-api-key / x-openai-api-key header or set OPENAI_API_KEY in .env.'
		);
	}

	const userContent: Array<Record<string, unknown>> = [];

	if (input.imageBytesBase64) {
		const rawMime = input.mimeType?.toLowerCase().trim();
		const mime = rawMime && rawMime.startsWith('image/') ? rawMime : 'image/jpeg';
		userContent.push({
			type: 'image_url',
			image_url: {
				url: `data:${mime};base64,${input.imageBytesBase64}`
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
${input.text?.trim() ? `\nUser provided text:\n${input.text.trim()}` : ''}
`;

	userContent.push({
		type: 'text',
		text: promptText
	});

	return callOpenAI(
		effectiveApiKey,
		[
			{ role: 'system', content: OPENAI_SCHEMA_PROMPT },
			{ role: 'user', content: userContent }
		],
		input.model
	);
}

export async function generateRoutineWithOpenAI(input: AiGenerateInput): Promise<any> {
	const effectiveApiKey = input.apiKey?.trim() || process.env.OPENAI_API_KEY?.trim();

	if (!effectiveApiKey) {
		throw new Error(
			'OpenAI API key not configured. Provide an sk-... key or set OPENAI_API_KEY in .env.'
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

	return callOpenAI(
		effectiveApiKey,
		[
			{ role: 'system', content: OPENAI_SCHEMA_PROMPT },
			{ role: 'user', content: prompt }
		],
		input.model
	);
}

const DEFAULT_OPENAI_MODELS = ['gpt-4o-mini', 'gpt-4o', 'o1-mini', 'o3-mini'];

export async function listOpenAIModels(apiKey: string): Promise<AiModelOption[]> {
	let modelIds = DEFAULT_OPENAI_MODELS;

	if (apiKey?.trim()) {
		try {
			const res = await fetch('https://api.openai.com/v1/models', {
				method: 'GET',
				headers: {
					Authorization: `Bearer ${apiKey.trim()}`
				},
				signal: AbortSignal.timeout(3500)
			});

			if (res.ok) {
				const data: any = await res.json();
				if (Array.isArray(data?.data)) {
					const available: string[] = data.data
						.map((m: any) => m.id as string)
						.filter((id: string) => {
							const lower = id.toLowerCase();
							return (
								(lower.startsWith('gpt-4o') ||
									lower.startsWith('o1') ||
									lower.startsWith('o3') ||
									lower.startsWith('chatgpt-4o')) &&
								!lower.includes('realtime') &&
								!lower.includes('audio') &&
								!lower.includes('transcription')
							);
						});

					if (available.length > 0) {
						const sorted = available.sort((a, b) => {
							const score = (m: string) => {
								if (m === 'gpt-4o-mini') return 100;
								if (m.startsWith('gpt-4o-mini')) return 90;
								if (m === 'gpt-4o') return 80;
								if (m.startsWith('gpt-4o')) return 70;
								if (m.includes('o3-mini')) return 60;
								if (m.includes('o1-mini')) return 50;
								return 10;
							};
							return score(b) - score(a);
						});

						modelIds = Array.from(new Set([...sorted, ...DEFAULT_OPENAI_MODELS]));
					}
				}
			}
		} catch {
			// Fallback to defaults
		}
	}

	return modelIds.map((id) => {
		let name = id;
		if (id === 'gpt-4o-mini') name = 'GPT-4o mini (Recommended Default)';
		else if (id === 'gpt-4o') name = 'GPT-4o (Vision & Advanced Reasoning)';
		else if (id === 'o3-mini') name = 'o3-mini (STEM Reasoning)';
		else if (id === 'o1-mini') name = 'o1-mini';
		else if (id === 'o1') name = 'o1 (Deep Reasoning)';

		return {
			id,
			name,
			provider: 'openai',
			isVision: id.includes('4o')
		};
	});
}

async function callOpenAI(
	apiKey: string,
	messages: Array<Record<string, unknown>>,
	explicitModel?: string
): Promise<any> {
	const model = explicitModel?.trim() || process.env.OPENAI_MODEL?.trim() || 'gpt-4o-mini';
	const url = 'https://api.openai.com/v1/chat/completions';

	const response = await fetch(url, {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			Authorization: `Bearer ${apiKey}`
		},
		body: JSON.stringify({
			model,
			messages,
			temperature: 0.1,
			response_format: { type: 'json_object' }
		})
	});

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

		throw new Error(apiMessage || `OpenAI API error (HTTP ${response.status})`);
	}

	const result: unknown = await response.json();
	const rawJsonText =
		typeof result === 'object' &&
		result !== null &&
		'choices' in result &&
		Array.isArray(result.choices) &&
		result.choices[0] &&
		typeof result.choices[0] === 'object' &&
		'message' in result.choices[0] &&
		result.choices[0].message &&
		typeof result.choices[0].message === 'object' &&
		'content' in result.choices[0].message &&
		typeof result.choices[0].message.content === 'string'
			? result.choices[0].message.content
			: null;

	if (!rawJsonText?.trim()) {
		throw new Error('OpenAI returned no valid content.');
	}

	try {
		return JSON.parse(rawJsonText);
	} catch {
		throw new Error('OpenAI returned a format that is not valid JSON.');
	}
}
