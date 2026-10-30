import test from 'node:test';
import assert from 'node:assert/strict';
import { detectProvider } from './types.ts';

test('detectProvider identifies OpenAI keys', () => {
	assert.equal(detectProvider('sk-proj-1234567890abcdef'), 'openai');
	assert.equal(detectProvider('sk-1234567890abcdef'), 'openai');
	assert.equal(detectProvider('org-1234567890abcdef'), 'openai');
});

test('detectProvider identifies Gemini keys or falls back', () => {
	assert.equal(detectProvider('AIzaSyD-1234567890abcdef'), 'gemini');
	assert.equal(detectProvider('random-key'), 'gemini');
});

test('detectProvider honors explicit provider preference', () => {
	assert.equal(detectProvider('AIzaSyD-key', 'openai'), 'openai');
	assert.equal(detectProvider('sk-key', 'gemini'), 'gemini');
});
