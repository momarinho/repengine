import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { listAvailableAiModels } from '$lib/server/ai';

export const POST: RequestHandler = async ({ request }) => {
	const body = await request.json().catch(() => ({}));
	const apiKey =
		request.headers.get('x-ai-api-key') ||
		request.headers.get('x-gemini-api-key') ||
		request.headers.get('x-openai-api-key') ||
		body.apiKey ||
		undefined;
	const provider =
		(request.headers.get('x-ai-provider') as any) ||
		body.provider ||
		undefined;

	try {
		const result = await listAvailableAiModels(apiKey, provider);
		return json(result);
	} catch (err: any) {
		console.error('[AI Models Error]', err);
		return json(
			{ message: err?.message || 'Falha ao buscar modelos de IA' },
			{ status: 500 }
		);
	}
};
