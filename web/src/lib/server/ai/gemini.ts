import type { AiGenerateInput, AiParseInput } from './types';

// Strict schema for Google Gemini Structured Output
const ROUTINE_SCHEMA = {
	type: 'OBJECT',
	properties: {
		name: { type: 'STRING', description: 'Nome da rotina de treino' },
		description: { type: 'STRING', description: 'Breve resumo do foco da rotina' },
		sections: {
			type: 'ARRAY',
			description: 'Dias da rotina (ex: Dia 1, Treino A, etc.)',
			items: {
				type: 'OBJECT',
				properties: {
					title: { type: 'STRING', description: 'Nome do dia (ex: Day 1 - Push)' },
					subtitle: { type: 'STRING', description: 'Músculos trabalhados' },
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
			'Chave de API do Gemini não configurada. Forneça uma chave no cabeçalho x-gemini-api-key ou defina GEMINI_API_KEY no .env.'
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
Você é um especialista em treinamento de força e periodização.
Sua missão é extrair ou converter as informações de treino fornecidas (seja imagem de ficha de academia, anotação manuscrita ou texto livre) para a estrutura formal de treino do RepEngine.

Regras importantes:
1. Identifique os dias de treino (ex: Treino A, Treino B, Dia 1, etc.) e mapeie para "sections".
2. Para cada exercício:
   - Se for exercício convencional, use node_type_slug: "exercise" com "sets", "reps", "load_value" (se houver carga indicada, caso contrário 0) e "rest_seconds" (padrão 90 se omitido).
   - Se for superset (dois exercícios combinados sem descanso), use node_type_slug: "superset" preenchendo exercise_a_name e exercise_b_name.
   - Se for aeróbio ou prancha com tempo, use node_type_slug: "exercise_timed" com "duration" em segundos.
3. Padronize os nomes dos exercícios para termos limpos e reconhecíveis (em português ou inglês padronizado).
4. Retorne somente o objeto JSON correspondente ao schema fornecido.
${input.text?.trim() ? `\nTexto fornecido pelo usuário:\n${input.text.trim()}` : ''}
`;

	parts.push({ text: promptText });

	return callGemini(effectiveApiKey, parts, ROUTINE_SCHEMA);
}

export async function generateRoutineWithGemini(input: AiGenerateInput): Promise<any> {
	const effectiveApiKey = input.apiKey?.trim() || process.env.GEMINI_API_KEY?.trim();

	if (!effectiveApiKey) {
		throw new Error(
			'Chave de API do Gemini não configurada. Forneça uma chave no cabeçalho x-gemini-api-key ou defina GEMINI_API_KEY no .env.'
		);
	}

	const prompt = `
Você é um treinador de alto nível e cientista do esporte. Crie uma rotina de treino estruturada e periodizada com base nas seguintes preferências:
- Objetivo principal: ${input.goal || 'Hipertrofia'}
- Divisão (Split): ${input.split || 'Full Body'}
- Nível do atleta: ${input.level || 'Intermediário'}
- Equipamentos disponíveis: ${input.equipment || 'Academia completa'}
- Restrições / Observações: ${input.constraints || 'Nenhuma'}
- Pedido específico do usuário: "${input.prompt}"

Regras:
1. Estruture a rotina em dias organizados (sections).
2. Para cada exercício, defina séries (sets), repetições (reps), carga estimada inicial em kg (load_value) e descanso em segundos (rest_seconds).
3. Use nomes claros e padronizados para os exercícios.
`;

	return callGemini(effectiveApiKey, [{ text: prompt }], ROUTINE_SCHEMA);
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

async function callGemini(apiKey: string, parts: Array<Record<string, unknown>>, schema: Record<string, unknown>): Promise<any> {
	const candidateModels = await resolveGeminiModels(apiKey);

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
				throw new Error('Chave de API do Gemini inválida. Por favor, verifique sua chave no campo BYOK.');
			}
			if (response.status === 429 || msgLower.includes('quota') || msgLower.includes('resource exhausted')) {
				throw new Error('Limite de requisições excedido na sua chave Gemini (Quota Exceeded). Aguarde alguns instantes ou use outra chave.');
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
				lastError = new Error(apiMessage || `Modelo ${model} indisponível (HTTP ${response.status})`);
				continue;
			}

			throw new Error(apiMessage || `Erro da API do Gemini (HTTP ${response.status})`);
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
			throw new Error('A IA não retornou nenhum conteúdo válido.');
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
			throw new Error('A IA retornou um formato que não pôde ser convertido para JSON válido.');
		}
	}

	throw lastError || new Error('Nenhum modelo Gemini compatível pôde responder.');
}
