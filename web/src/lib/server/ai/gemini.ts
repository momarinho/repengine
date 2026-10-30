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

	if (input.imageBytesBase64 && input.mimeType) {
		parts.push({
			inlineData: {
				mimeType: input.mimeType,
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

async function callGemini(apiKey: string, parts: Array<Record<string, unknown>>, schema: Record<string, unknown>): Promise<any> {
	const candidateModels = [
		process.env.GEMINI_MODEL,
		'gemini-2.5-flash',
		'gemini-2.0-flash',
		'gemini-1.5-flash'
	].filter(Boolean) as string[];

	let lastError: Error | null = null;

	for (const model of candidateModels) {
		const url = new URL(
			`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`
		);
		url.searchParams.set('key', apiKey);

		const response = await fetch(url, {
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

			// If model is not found / 404, try next candidate
			if (response.status === 404 || apiMessage?.includes('not found') || apiMessage?.includes('deprecated')) {
				lastError = new Error(apiMessage || `Modelo ${model} indisponível (HTTP 404)`);
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

		try {
			return JSON.parse(rawJsonText);
		} catch {
			throw new Error('A IA retornou um formato que não é um JSON válido.');
		}
	}

	throw lastError || new Error('Nenhum modelo Gemini compatível pôde responder.');
}
