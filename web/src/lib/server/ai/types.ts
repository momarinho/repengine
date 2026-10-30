export type AiProvider = 'gemini' | 'openai';

export type AiParseInput = {
	text?: string;
	imageBytesBase64?: string;
	mimeType?: string;
	apiKey?: string;
	provider?: 'auto' | AiProvider;
};

export type AiGenerateInput = {
	prompt: string;
	goal?: string;
	split?: string;
	level?: string;
	equipment?: string;
	constraints?: string;
	apiKey?: string;
	provider?: 'auto' | AiProvider;
};

export function detectProvider(apiKey?: string, explicitProvider?: string): AiProvider {
	if (explicitProvider === 'openai' || explicitProvider === 'gemini') {
		return explicitProvider;
	}

	const trimmed = apiKey?.trim();
	if (trimmed) {
		if (trimmed.startsWith('sk-') || trimmed.startsWith('org-') || trimmed.startsWith('proj_')) {
			return 'openai';
		}
		return 'gemini';
	}

	// Environment variable fallback
	if (process.env.OPENAI_API_KEY && !process.env.GEMINI_API_KEY) {
		return 'openai';
	}

	return 'gemini';
}
