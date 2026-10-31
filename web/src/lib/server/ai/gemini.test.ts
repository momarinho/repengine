import test from 'node:test';
import assert from 'node:assert/strict';
import { parseRoutineWithGemini, resolveGeminiModels } from './gemini.ts';

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

test('resolveGeminiModels honors GEMINI_MODEL env var', async () => {
	const originalModel = process.env.GEMINI_MODEL;
	process.env.GEMINI_MODEL = 'gemini-custom-pro';

	try {
		const models = await resolveGeminiModels('dummy-key');
		assert.equal(models[0], 'gemini-custom-pro');
	} finally {
		if (originalModel !== undefined) {
			process.env.GEMINI_MODEL = originalModel;
		} else {
			delete process.env.GEMINI_MODEL;
		}
	}
});

test('resolveGeminiModels falls back to modern 2026 models and excludes deprecated 1.5 models', async () => {
	const originalModel = process.env.GEMINI_MODEL;
	delete process.env.GEMINI_MODEL;

	try {
		const models = await resolveGeminiModels('dummy-key');
		assert.ok(models.includes('gemini-2.5-flash'));
		assert.ok(models.includes('gemini-2.0-flash'));
		assert.ok(!models.includes('gemini-1.5-flash'), 'Must not include retired gemini-1.5-flash');
		assert.ok(!models.includes('gemini-1.5-pro'), 'Must not include retired gemini-1.5-pro');
	} finally {
		if (originalModel !== undefined) {
			process.env.GEMINI_MODEL = originalModel;
		}
	}
});
