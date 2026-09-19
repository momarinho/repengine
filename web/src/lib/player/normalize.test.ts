import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizePlayerRoutine } from './normalize.ts';
import type { Workflow } from '../editor/types.ts';

test('normalizePlayerRoutine defaults restSeconds to 90 for exercise when missing', () => {
	const workflow: Workflow = {
		id: 1,
		user_id: 1,
		name: 'Test Workflow',
		description: 'Test',
		is_public: false,
		created_at: '',
		updated_at: '',
		blocks: [
			{
				id: 101,
				workflow_id: 1,
				node_type_slug: 'exercise',
				position: 0,
				data: {
					exercise_name: 'Bicep Curl',
					sets: 3,
					reps: '10'
				}
			}
		]
	};

	const routine = normalizePlayerRoutine(workflow);
	assert.ok(routine);
	assert.equal(routine.blocks.length, 1);
	assert.equal(routine.blocks[0].restSeconds, 90);
});

test('normalizePlayerRoutine defaults restSeconds to 120 for linear_progression, superset, and wave when missing', () => {
	const workflow: Workflow = {
		id: 1,
		user_id: 1,
		name: 'Test Workflow',
		description: 'Test',
		is_public: false,
		created_at: '',
		updated_at: '',
		blocks: [
			{
				id: 101,
				workflow_id: 1,
				node_type_slug: 'linear_progression',
				position: 0,
				data: {
					exercise_name: 'Squat',
					sets: 3,
					reps: '5'
				}
			},
			{
				id: 102,
				workflow_id: 1,
				node_type_slug: 'superset',
				position: 1,
				data: {
					exercise_a_name: 'Pull-up',
					exercise_b_name: 'Dip',
					sets: 3
				}
			},
			{
				id: 103,
				workflow_id: 1,
				node_type_slug: 'wave',
				position: 2,
				data: {
					exercise_name: 'Deadlift',
					active_week: 1,
					week_1_reps: '5/5/5+'
				}
			}
		]
	};

	const routine = normalizePlayerRoutine(workflow);
	assert.ok(routine);
	assert.equal(routine.blocks[0].restSeconds, 120);
	assert.equal(routine.blocks[1].restSeconds, 120);
	assert.equal(routine.blocks[2].restSeconds, 120);
});

test('normalizePlayerRoutine preserves explicit restSeconds including 0', () => {
	const workflow: Workflow = {
		id: 1,
		user_id: 1,
		name: 'Test Workflow',
		description: 'Test',
		is_public: false,
		created_at: '',
		updated_at: '',
		blocks: [
			{
				id: 101,
				workflow_id: 1,
				node_type_slug: 'exercise',
				position: 0,
				data: {
					exercise_name: 'Fast Abs',
					sets: 3,
					reps: '15',
					rest_seconds: 0
				}
			},
			{
				id: 102,
				workflow_id: 1,
				node_type_slug: 'exercise',
				position: 1,
				data: {
					exercise_name: 'Heavy Bench',
					sets: 3,
					reps: '5',
					rest_seconds: 180
				}
			}
		]
	};

	const routine = normalizePlayerRoutine(workflow);
	assert.ok(routine);
	assert.equal(routine.blocks[0].restSeconds, 0);
	assert.equal(routine.blocks[1].restSeconds, 180);
});

test('normalizePlayerRoutine parses string numeric rest_seconds and sets', () => {
	const workflow: Workflow = {
		id: 1,
		user_id: 1,
		name: 'Test Workflow',
		description: 'Test',
		is_public: false,
		created_at: '',
		updated_at: '',
		blocks: [
			{
				id: 101,
				workflow_id: 1,
				node_type_slug: 'exercise',
				position: 0,
				data: {
					exercise_name: 'Leg Press',
					sets: '4',
					reps: '12',
					rest_seconds: '75'
				}
			}
		]
	};

	const routine = normalizePlayerRoutine(workflow);
	assert.ok(routine);
	assert.equal(routine.blocks[0].sets, 4);
	assert.equal(routine.blocks[0].restSeconds, 75);
});
