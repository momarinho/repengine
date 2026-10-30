import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { parseRoutineWithAi } from '$lib/server/ai';

export const POST: RequestHandler = async ({ request }) => {
	const clientApiKey =
		request.headers.get('x-ai-api-key') ||
		request.headers.get('x-gemini-api-key') ||
		request.headers.get('x-openai-api-key') ||
		undefined;
	const clientProvider = request.headers.get('x-ai-provider') as 'gemini' | 'openai' | undefined;
	const contentType = request.headers.get('content-type') || '';

	try {
		let text: string | undefined;
		let imageBytesBase64: string | undefined;
		let mimeType: string | undefined;

		if (contentType.includes('multipart/form-data')) {
			const formData = await request.formData();
			text = (formData.get('text') as string) || undefined;
			const file = formData.get('file') as File | null;

			if (file && file.size > 0) {
				mimeType = file.type;
				const arrayBuffer = await file.arrayBuffer();
				imageBytesBase64 = Buffer.from(arrayBuffer).toString('base64');
			}
		} else {
			const body = await request.json();
			text = body.text;
			imageBytesBase64 = body.imageBytesBase64;
			mimeType = body.mimeType;
		}

		if (!text && !imageBytesBase64) {
			return json(
				{
					message: 'Envie uma imagem da ficha ou um texto para ser analisado.'
				},
				{ status: 400 }
			);
		}

		const parsedRoutine = await parseRoutineWithAi({
			text,
			imageBytesBase64,
			mimeType,
			apiKey: clientApiKey,
			provider: clientProvider
		});

		return json(parsedRoutine);
	} catch (err: any) {
		return json(
			{ message: err?.message || 'Falha ao processar treino com IA' },
			{ status: 500 }
		);
	}
};
