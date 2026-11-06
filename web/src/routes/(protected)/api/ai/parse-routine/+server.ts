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
	const clientModel = request.headers.get('x-ai-model') || undefined;
	const contentType = request.headers.get('content-type') || '';

	try {
		let text: string | undefined;
		let imageBytesBase64: string | undefined;
		let mimeType: string | undefined;
		let requestedModel = clientModel;

		if (contentType.includes('multipart/form-data')) {
			const formData = await request.formData();
			text = (formData.get('text') as string) || undefined;
			if (!requestedModel) {
				requestedModel = (formData.get('model') as string) || undefined;
			}
			const file = formData.get('file') as File | null;

			if (file && file.size > 0) {
				const arrayBuffer = await file.arrayBuffer();
				const buffer = Buffer.from(arrayBuffer);
				imageBytesBase64 = buffer.toString('base64');

				// Defensive MIME type detection: check magic bytes or file extension
				let detectedMime = file.type?.toLowerCase().trim();
				if (!detectedMime || detectedMime === 'application/octet-stream') {
					if (buffer.length > 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
						detectedMime = 'image/jpeg';
					} else if (
						buffer.length > 4 &&
						buffer[0] === 0x89 &&
						buffer[1] === 0x50 &&
						buffer[2] === 0x4e &&
						buffer[3] === 0x47
					) {
						detectedMime = 'image/png';
					} else if (file.name.toLowerCase().endsWith('.png')) {
						detectedMime = 'image/png';
					} else if (file.name.toLowerCase().endsWith('.webp')) {
						detectedMime = 'image/webp';
					} else {
						detectedMime = 'image/jpeg';
					}
				}
				mimeType = detectedMime;
			}
		} else {
			const body = await request.json();
			text = body.text;
			imageBytesBase64 = body.imageBytesBase64;
			mimeType = body.mimeType || (imageBytesBase64 ? 'image/jpeg' : undefined);
			if (!requestedModel) {
				requestedModel = body.model;
			}
		}

		if (!text && !imageBytesBase64) {
			return json(
				{
					message: 'Provide a routine image or text description to analyze.'
				},
				{ status: 400 }
			);
		}

		const hasServerKey = Boolean(
			process.env.GEMINI_API_KEY?.trim() || process.env.OPENAI_API_KEY?.trim()
		);
		if (!clientApiKey && !hasServerKey) {
			return json(
				{
					message:
						'No API key configured. Please enter your free Google Gemini key or OpenAI key in the "Personal API Key (BYOK)" field.'
				},
				{ status: 400 }
			);
		}

		const parsedRoutine = await parseRoutineWithAi({
			text,
			imageBytesBase64,
			mimeType,
			apiKey: clientApiKey,
			provider: clientProvider,
			model: requestedModel
		});

		return json(parsedRoutine);
	} catch (err: any) {
		console.error('[AI Parse Error]', err);
		return json(
			{ message: err?.message || 'Failed to process routine with AI' },
			{ status: 500 }
		);
	}
};
