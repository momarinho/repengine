import { detectProvider, type AiGenerateInput, type AiParseInput, type AiProvider } from './types';
import { generateRoutineWithGemini, parseRoutineWithGemini } from './gemini';
import { generateRoutineWithOpenAI, parseRoutineWithOpenAI } from './openai';

export * from './types';
export { parseRoutineWithGemini, generateRoutineWithGemini } from './gemini';
export { parseRoutineWithOpenAI, generateRoutineWithOpenAI } from './openai';

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
