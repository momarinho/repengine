import { detectProvider, type AiGenerateInput, type AiModelOption, type AiParseInput, type AiProvider } from './types.ts';
import { generateRoutineWithGemini, listGeminiModels, parseRoutineWithGemini } from './gemini.ts';
import { generateRoutineWithOpenAI, listOpenAIModels, parseRoutineWithOpenAI } from './openai.ts';

export * from './types.ts';
export { parseRoutineWithGemini, generateRoutineWithGemini, listGeminiModels } from './gemini.ts';
export { parseRoutineWithOpenAI, generateRoutineWithOpenAI, listOpenAIModels } from './openai.ts';

export async function listAvailableAiModels(
	apiKey?: string,
	providerPref?: string
): Promise<{ provider: AiProvider; models: AiModelOption[] }> {
	const provider = detectProvider(apiKey, providerPref);
	const key =
		apiKey?.trim() ||
		(provider === 'openai' ? process.env.OPENAI_API_KEY?.trim() : process.env.GEMINI_API_KEY?.trim()) ||
		'';

	if (provider === 'openai') {
		const models = await listOpenAIModels(key);
		return { provider: 'openai', models };
	}

	const models = await listGeminiModels(key);
	return { provider: 'gemini', models };
}

export async function parseRoutineWithAi(input: AiParseInput): Promise<any> {
	const provider = detectProvider(input.apiKey, input.provider);

	if (provider === 'openai') {
		return parseRoutineWithOpenAI(input);
	}

	return parseRoutineWithGemini(input);
}

export async function generateRoutineWithAi(input: AiGenerateInput): Promise<any> {
	const provider = detectProvider(input.apiKey, input.provider);

	if (provider === 'openai') {
		return generateRoutineWithOpenAI(input);
	}

	return generateRoutineWithGemini(input);
}
