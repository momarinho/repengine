import test from 'node:test';
import assert from 'node:assert/strict';
import { parseRoutineWithGemini } from './gemini.ts';

test('parseRoutineWithGemini throws when no API key is provided or found in environment', async () => {
	const originalKey = process.env.GEMINI_API_KEY;
	delete process.env.GEMINI_API_KEY;

	try {
		await assert.rejects(
			async () => {
				await parseRoutineWithGemini({
					text: 'Supino 4x10'
				});
			},
			{
				message: /Chave de API do Gemini não configurada/
			}
		);
	} finally {
		if (originalKey !== undefined) {
			process.env.GEMINI_API_KEY = originalKey;
		}
	}
});
