import type { Workflow, WorkflowBlockApi } from '$lib/editor/types';
import type { WorkoutSession, WorkoutSetLog } from '$lib/workout-sessions/types';
import {
	computeDemo1RM,
	computeDemoACWR,
	computeDemoAnalytics,
	computeDemoAutoregulation,
	evaluateDemoSessionProgression
} from './progression';
import { createInitialDemoState, DEMO_NODE_TYPES, type DemoState } from './seed';

const globalForDemo = globalThis as unknown as { __repengineDemoState?: DemoState };

function getStore(): DemoState {
	if (!globalForDemo.__repengineDemoState) {
		globalForDemo.__repengineDemoState = createInitialDemoState();
	}
	return globalForDemo.__repengineDemoState;
}

function jsonRes(body: unknown, status = 200): Response {
	if (status === 204) {
		return new Response(null, { status: 204 });
	}
	return new Response(JSON.stringify(body), {
		status,
		headers: { 'Content-Type': 'application/json' }
	});
}

function parseBody(init?: RequestInit): Record<string, any> {
	if (!init?.body || typeof init.body !== 'string') return {};
	try {
		return JSON.parse(init.body) as Record<string, any>;
	} catch {
		return {};
	}
}

function findSession(store: DemoState, sessionId: number): WorkoutSession | undefined {
	for (const list of Object.values(store.sessionsByWorkflow)) {
		const found = list.find((s) => s.id === sessionId);
		if (found) return found;
	}
	return undefined;
}

function enrichWorkflowSummary(store: DemoState, w: Workflow): Workflow & { block_count: number } {
	return {
		...w,
		block_count: w.blocks?.length ?? 0
	};
}

export async function handleDemoApiFetch(path: string, init: RequestInit = {}): Promise<Response> {
	const store = getStore();
	const method = (init.method || 'GET').toUpperCase();
	const [pathname, queryStr = ''] = path.split('?');
	const search = new URLSearchParams(queryStr);
	const body = parseBody(init);

	// --- Auth endpoints ---
	if (pathname === '/auth/me') {
		if (method === 'GET') {
			return jsonRes({
				user_id: 1,
				email: 'athlete@repengine.demo',
				created_at: '2026-09-01T12:00:00.000Z',
				updated_at: '2026-11-01T12:00:00.000Z'
			});
		}
		return jsonRes({
			message: 'Demo showcase account is read-only.'
		}, 400);
	}
	if (pathname === '/auth/login') {
		return jsonRes({ token: 'demo-showcase-token' });
	}
	if (pathname === '/auth/register') {
		return jsonRes({ user_id: 1, email: body.email || 'athlete@repengine.demo' }, 201);
	}
	if (pathname === '/auth/logout') {
		return jsonRes({ ok: true });
	}
	if (pathname.startsWith('/auth/password-reset')) {
		return jsonRes({ message: 'Demo showcase: password reset request simulated.' });
	}

	// --- Node Types ---
	if (pathname === '/node-types' && method === 'GET') {
		return jsonRes(DEMO_NODE_TYPES);
	}

	// --- Training Maxes ---
	if (pathname === '/training-maxes') {
		if (method === 'GET') {
			return jsonRes(store.trainingMaxes);
		}
		if (method === 'POST' || method === 'PUT') {
			const name = String(body.exercise_name ?? '').trim();
			const value = Number(body.value ?? 0);
			const unit = String(body.unit ?? 'kg');
			if (!name || !Number.isFinite(value) || value <= 0) {
				return jsonRes({ message: 'Valid exercise_name and positive value are required.' }, 400);
			}
			const existingIdx = store.trainingMaxes.findIndex(
				(tm) => tm.exercise_name.toLowerCase() === name.toLowerCase()
			);
			const now = new Date().toISOString();
			if (existingIdx >= 0) {
				store.trainingMaxes[existingIdx] = {
					...store.trainingMaxes[existingIdx],
					value,
					unit,
					updated_at: now
				};
				return jsonRes(store.trainingMaxes[existingIdx]);
			}
			const created = {
				id: store.trainingMaxes.length + 1,
				user_id: 1,
				exercise_name: name,
				value,
				unit,
				updated_at: now
			};
			store.trainingMaxes.push(created);
			return jsonRes(created, 201);
		}
	}

	// --- Templates & Clone Jobs ---
	if (pathname === '/templates' && method === 'GET') {
		const category = (search.get('category') || '').toLowerCase();
		const filtered = category
			? store.templates.filter((t) => t.category.toLowerCase() === category)
			: store.templates;
		return jsonRes({
			data: filtered,
			next_cursor: null,
			has_more: false
		});
	}

	const templateCloneMatch = pathname.match(/^\/templates\/(\d+)\/clone$/);
	if (templateCloneMatch && method === 'POST') {
		const templateId = Number(templateCloneMatch[1]);
		const tpl = store.templates.find((t) => t.id === templateId);
		if (!tpl) {
			return jsonRes({ message: 'Template not found.' }, 404);
		}
		const newWorkflowId = store.nextWorkflowId++;
		const now = new Date().toISOString();
		const clonedBlocks: WorkflowBlockApi[] = (tpl.blocks ?? []).map((b, idx) => ({
			id: store.nextBlockId++,
			workflow_id: newWorkflowId,
			node_type_slug: b.node_type_slug,
			position: b.position ?? idx,
			data: JSON.parse(JSON.stringify(b.data ?? {}))
		}));
		const newWorkflow: Workflow = {
			id: newWorkflowId,
			user_id: 1,
			name: `${tpl.name} (Copy)`,
			description: tpl.description,
			is_public: false,
			created_at: now,
			updated_at: now,
			blocks: clonedBlocks
		};
		store.workflows.unshift(newWorkflow);
		store.versionsByWorkflow[newWorkflowId] = [];
		store.progressionStatesByWorkflow[newWorkflowId] = [];
		store.sessionsByWorkflow[newWorkflowId] = [];

		const jobId = store.nextCloneJobId++;
		store.cloneJobs[jobId] = {
			id: jobId,
			template_id: templateId,
			user_id: 1,
			workflow_id: newWorkflowId,
			idempotency_key: `demo-${jobId}`,
			status: 'completed',
			attempts: 1,
			error_message: '',
			created_at: now,
			updated_at: now
		};
		return jsonRes({ job_id: jobId, status: 'completed', workflow_id: newWorkflowId }, 201);
	}

	const templateDetailMatch = pathname.match(/^\/templates\/(\d+)$/);
	if (templateDetailMatch && method === 'GET') {
		const id = Number(templateDetailMatch[1]);
		const tpl = store.templates.find((t) => t.id === id);
		if (!tpl) return jsonRes({ message: 'Template not found.' }, 404);
		return jsonRes(tpl);
	}

	const cloneJobMatch = pathname.match(/^\/clone-jobs\/(\d+)$/);
	if (cloneJobMatch && method === 'GET') {
		const jobId = Number(cloneJobMatch[1]);
		const job = store.cloneJobs[jobId];
		if (!job) return jsonRes({ message: 'Clone job not found.' }, 404);
		return jsonRes(job);
	}

	// --- Workflows list / create ---
	if (pathname === '/workflows') {
		if (method === 'GET') {
			const limit = Number(search.get('limit') || '0');
			const list = store.workflows.map((w) => enrichWorkflowSummary(store, w));
			return jsonRes({
				data: limit > 0 ? list.slice(0, limit) : list,
				next_cursor: null,
				has_more: false
			});
		}
		if (method === 'POST') {
			const id = store.nextWorkflowId++;
			const now = new Date().toISOString();
			const blocks: WorkflowBlockApi[] = Array.isArray(body.blocks)
				? body.blocks.map((b: any, idx: number) => ({
						id: store.nextBlockId++,
						workflow_id: id,
						node_type_slug: String(b.node_type_slug ?? 'exercise'),
						position: Number(b.position ?? idx),
						data: b.data ?? {}
					}))
				: [];
			const workflow: Workflow = {
				id,
				user_id: 1,
				name: String(body.name || 'Untitled Routine'),
				description: String(body.description || ''),
				is_public: Boolean(body.is_public),
				created_at: now,
				updated_at: now,
				blocks
			};
			store.workflows.unshift(workflow);
			store.versionsByWorkflow[id] = [];
			store.progressionStatesByWorkflow[id] = [];
			store.sessionsByWorkflow[id] = [];
			return jsonRes(workflow, 201);
		}
	}

	// --- Workflow sub-resources ---
	const wfAnalyticsMatch = pathname.match(/^\/workflows\/(\d+)\/analytics$/);
	if (wfAnalyticsMatch && method === 'GET') {
		const wfId = Number(wfAnalyticsMatch[1]);
		const sessions = store.sessionsByWorkflow[wfId] ?? [];
		return jsonRes(computeDemoAnalytics(wfId, sessions));
	}

	const wfProgMatch = pathname.match(/^\/workflows\/(\d+)\/progression-states$/);
	if (wfProgMatch && method === 'GET') {
		const wfId = Number(wfProgMatch[1]);
		return jsonRes(store.progressionStatesByWorkflow[wfId] ?? []);
	}

	const wfVersionsMatch = pathname.match(/^\/workflows\/(\d+)\/versions$/);
	if (wfVersionsMatch) {
		const wfId = Number(wfVersionsMatch[1]);
		const wf = store.workflows.find((w) => w.id === wfId);
		if (!wf) return jsonRes({ message: 'Routine not found.' }, 404);
		if (method === 'GET') {
			return jsonRes({
				data: store.versionsByWorkflow[wfId] ?? [],
				next_cursor: null,
				has_more: false
			});
		}
		if (method === 'POST') {
			const versions = store.versionsByWorkflow[wfId] ?? [];
			const nextNum = (versions[0]?.version_number ?? 0) + 1;
			const version = {
				id: store.nextVersionId++,
				workflow_id: wfId,
				version_number: nextNum,
				snapshot: {
					name: wf.name,
					blocks: JSON.parse(JSON.stringify(wf.blocks ?? []))
				},
				commit_message: String(body.commit_message || `Snapshot v${nextNum}`),
				created_at: new Date().toISOString()
			};
			store.versionsByWorkflow[wfId] = [version, ...versions];
			return jsonRes(version, 201);
		}
	}

	const wfVersionRestoreMatch = pathname.match(/^\/workflows\/(\d+)\/versions\/(\d+)\/restore$/);
	if (wfVersionRestoreMatch && method === 'POST') {
		const wfId = Number(wfVersionRestoreMatch[1]);
		const versionId = Number(wfVersionRestoreMatch[2]);
		const wf = store.workflows.find((w) => w.id === wfId);
		const version = (store.versionsByWorkflow[wfId] ?? []).find((v) => v.id === versionId);
		if (!wf || !version) return jsonRes({ message: 'Version not found.' }, 404);
		const snapBlocks = Array.isArray((version.snapshot as any)?.blocks)
			? (version.snapshot as any).blocks
			: wf.blocks;
		wf.blocks = JSON.parse(JSON.stringify(snapBlocks));
		wf.updated_at = new Date().toISOString();
		return jsonRes(wf);
	}

	const wfSessionsMatch = pathname.match(/^\/workflows\/(\d+)\/sessions$/);
	if (wfSessionsMatch) {
		const wfId = Number(wfSessionsMatch[1]);
		const wf = store.workflows.find((w) => w.id === wfId);
		if (!wf) return jsonRes({ message: 'Routine not found.' }, 404);
		if (method === 'GET') {
			const limit = Number(search.get('limit') || '30');
			const list = store.sessionsByWorkflow[wfId] ?? [];
			return jsonRes({
				data: list.slice(0, limit),
				next_cursor: null,
				has_more: false
			});
		}
		if (method === 'POST') {
			const now = new Date().toISOString();
			const session: WorkoutSession = {
				id: store.nextSessionId++,
				workflow_id: wfId,
				user_id: 1,
				section_id: String(body.section_id ?? ''),
				section_title: String(body.section_title ?? ''),
				status: 'active',
				started_at: now,
				completed_at: null,
				notes: '',
				log_count: 0,
				logs: []
			};
			store.sessionsByWorkflow[wfId] = [session, ...(store.sessionsByWorkflow[wfId] ?? [])];
			return jsonRes(session, 201);
		}
	}

	const wfDetailMatch = pathname.match(/^\/workflows\/(\d+)$/);
	if (wfDetailMatch) {
		const wfId = Number(wfDetailMatch[1]);
		const wfIdx = store.workflows.findIndex((w) => w.id === wfId);
		if (wfIdx < 0) return jsonRes({ message: 'Routine not found.' }, 404);

		if (method === 'GET') {
			return jsonRes(store.workflows[wfIdx]);
		}
		if (method === 'PUT') {
			const existing = store.workflows[wfIdx];
			const updatedBlocks: WorkflowBlockApi[] = Array.isArray(body.blocks)
				? body.blocks.map((b: any, idx: number) => ({
						id: typeof b.id === 'number' && b.id > 0 ? b.id : store.nextBlockId++,
						workflow_id: wfId,
						node_type_slug: String(b.node_type_slug ?? 'exercise'),
						position: Number(b.position ?? idx),
						data: b.data ?? {}
					}))
				: existing.blocks ?? [];
			const updated: Workflow = {
				...existing,
				name: body.name !== undefined ? String(body.name) : existing.name,
				description: body.description !== undefined ? String(body.description) : existing.description,
				is_public: body.is_public !== undefined ? Boolean(body.is_public) : existing.is_public,
				updated_at: new Date().toISOString(),
				blocks: updatedBlocks
			};
			store.workflows[wfIdx] = updated;
			return jsonRes(updated);
		}
		if (method === 'DELETE') {
			store.workflows.splice(wfIdx, 1);
			return jsonRes(null, 204);
		}
	}

	// --- Workout Session endpoints ---
	const sessionLogUpdateMatch = pathname.match(/^\/workout-sessions\/(\d+)\/logs\/(\d+)$/);
	if (sessionLogUpdateMatch && (method === 'PUT' || method === 'PATCH')) {
		const sessionId = Number(sessionLogUpdateMatch[1]);
		const logId = Number(sessionLogUpdateMatch[2]);
		const session = findSession(store, sessionId);
		if (!session) return jsonRes({ message: 'Session not found.' }, 404);
		session.logs = session.logs ?? [];
		const idx = session.logs.findIndex((l) => l.id === logId);
		if (idx < 0) return jsonRes({ message: 'Log not found.' }, 404);
		session.logs[idx] = {
			...session.logs[idx],
			actual_reps: body.actual_reps !== undefined ? String(body.actual_reps) : session.logs[idx].actual_reps,
			actual_load: body.actual_load !== undefined ? String(body.actual_load) : session.logs[idx].actual_load,
			actual_rpe: body.actual_rpe !== undefined ? String(body.actual_rpe) : session.logs[idx].actual_rpe,
			actual_rir: body.actual_rir !== undefined ? String(body.actual_rir) : session.logs[idx].actual_rir,
			completed: body.completed !== undefined ? Boolean(body.completed) : session.logs[idx].completed,
			notes: body.notes !== undefined ? String(body.notes) : session.logs[idx].notes
		};
		return jsonRes(session.logs[idx]);
	}

	const sessionLogsMatch = pathname.match(/^\/workout-sessions\/(\d+)\/logs$/);
	if (sessionLogsMatch && method === 'POST') {
		const sessionId = Number(sessionLogsMatch[1]);
		const session = findSession(store, sessionId);
		if (!session) return jsonRes({ message: 'Session not found.' }, 404);
		session.logs = session.logs ?? [];
		const blockId = body.workflow_block_id ? Number(body.workflow_block_id) : null;
		const clientId = String(body.block_client_id ?? '');
		const setIndex = Number(body.set_index ?? 1);
		const existingIdx = session.logs.findIndex(
			(l) => l.block_client_id === clientId && l.set_index === setIndex
		);
		const logEntry: WorkoutSetLog = {
			id: existingIdx >= 0 ? session.logs[existingIdx].id : store.nextLogId++,
			session_id: sessionId,
			workflow_block_id: blockId,
			block_client_id: clientId,
			node_type_slug: String(body.node_type_slug ?? 'exercise'),
			set_index: setIndex,
			prescribed_reps: String(body.prescribed_reps ?? ''),
			prescribed_load: String(body.prescribed_load ?? ''),
			prescribed_intensity: String(body.prescribed_intensity ?? ''),
			prescribed_rpe: String(body.prescribed_rpe ?? ''),
			actual_reps: String(body.actual_reps ?? ''),
			actual_load: String(body.actual_load ?? ''),
			actual_rpe: String(body.actual_rpe ?? ''),
			actual_rir: String(body.actual_rir ?? ''),
			completed: body.completed !== undefined ? Boolean(body.completed) : true,
			notes: String(body.notes ?? ''),
			created_at: new Date().toISOString()
		};
		if (existingIdx >= 0) {
			session.logs[existingIdx] = logEntry;
		} else {
			session.logs.push(logEntry);
		}
		session.log_count = session.logs.length;
		return jsonRes(logEntry, 201);
	}

	const sessionCompleteMatch = pathname.match(/^\/workout-sessions\/(\d+)\/complete$/);
	if (sessionCompleteMatch && method === 'POST') {
		const sessionId = Number(sessionCompleteMatch[1]);
		const session = findSession(store, sessionId);
		if (!session) return jsonRes({ message: 'Session not found.' }, 404);
		session.status = 'completed';
		session.completed_at = new Date().toISOString();
		if (body.notes !== undefined) session.notes = String(body.notes);

		const wf = store.workflows.find((w) => w.id === session.workflow_id);
		if (wf) {
			const existing = store.progressionStatesByWorkflow[wf.id] ?? [];
			store.progressionStatesByWorkflow[wf.id] = evaluateDemoSessionProgression(
				wf,
				session,
				existing,
				Boolean(body.is_deload)
			);
		}
		return jsonRes(session);
	}

	const sessionAbandonMatch = pathname.match(/^\/workout-sessions\/(\d+)\/abandon$/);
	if (sessionAbandonMatch && method === 'POST') {
		const sessionId = Number(sessionAbandonMatch[1]);
		const session = findSession(store, sessionId);
		if (!session) return jsonRes({ message: 'Session not found.' }, 404);
		session.status = 'abandoned';
		session.completed_at = new Date().toISOString();
		return jsonRes(session);
	}

	const sessionDetailMatch = pathname.match(/^\/workout-sessions\/(\d+)$/);
	if (sessionDetailMatch && method === 'GET') {
		const sessionId = Number(sessionDetailMatch[1]);
		const session = findSession(store, sessionId);
		if (!session) return jsonRes({ message: 'Session not found.' }, 404);
		return jsonRes(session);
	}

	return jsonRes({ message: `Demo route not implemented: ${method} ${pathname}` }, 404);
}

export async function handleDemoAnalyticsFetch(
	path: string,
	init: RequestInit = {}
): Promise<Response> {
	const body = parseBody(init);
	if (path === '/api/v1/1rm') {
		return jsonRes(computeDemo1RM(body));
	}
	if (path === '/api/v1/autoregulation') {
		return jsonRes(computeDemoAutoregulation(body));
	}
	if (path === '/api/v1/acwr') {
		return jsonRes(computeDemoACWR(body));
	}
	return jsonRes({ message: 'Demo analytics route not found' }, 404);
}
