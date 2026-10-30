import type { AiGenerateInput, AiParseInput } from './types';

const OPENAI_SCHEMA_PROMPT = `
Você deve responder ESTRITAMENTE com um objeto JSON válido, sem texto explicativo antes ou depois.
O JSON deve seguir rigorosamente a estrutura abaixo:
{
  "name": "Nome da Rotina",
  "description": "Descrição sucinta",
  "sections": [
    {
      "title": "Day 1 - Push",
      "subtitle": "Peito, Ombros e Tríceps",
      "kind": "day",
      "blocks": [
        {
          "node_type_slug": "exercise",
          "exercise_name": "Supino Reto",
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
          "exercise_name": "Prancha",
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
			'Chave de API da OpenAI não configurada. Forneça uma chave sk-... no cabeçalho x-gemini-api-key / x-openai-api-key ou defina OPENAI_API_KEY no .env.'
		);
	}

	const userContent: Array<Record<string, unknown>> = [];

	if (input.imageBytesBase64 && input.mimeType) {
		userContent.push({
			type: 'image_url',
			image_url: {
				url: `data:${input.mimeType};base64,${input.imageBytesBase64}`
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
${input.text?.trim() ? `\nTexto fornecido pelo usuário:\n${input.text.trim()}` : ''}
`;

	userContent.push({
		type: 'text',
		text: promptText
	});

	return callOpenAI(effectiveApiKey, [
		{ role: 'system', content: OPENAI_SCHEMA_PROMPT },
		{ role: 'user', content: userContent }
	]);
}

export async function generateRoutineWithOpenAI(input: AiGenerateInput): Promise<any> {
	const effectiveApiKey = input.apiKey?.trim() || process.env.OPENAI_API_KEY?.trim();

	if (!effectiveApiKey) {
		throw new Error(
			'Chave de API da OpenAI não configurada. Forneça uma chave sk-... ou defina OPENAI_API_KEY no .env.'
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

	return callOpenAI(effectiveApiKey, [
		{ role: 'system', content: OPENAI_SCHEMA_PROMPT },
		{ role: 'user', content: prompt }
	]);
}

async function callOpenAI(apiKey: string, messages: Array<Record<string, unknown>>): Promise<any> {
	const model = 'gpt-4o-mini';
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

		throw new Error(apiMessage || `Erro da API da OpenAI (HTTP ${response.status})`);
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
		throw new Error('A OpenAI não retornou nenhum conteúdo válido.');
	}

	try {
		return JSON.parse(rawJsonText);
	} catch {
		throw new Error('A OpenAI retornou um formato que não é um JSON válido.');
	}
}
