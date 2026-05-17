# RepEngine

RepEngine is a full-stack training routine builder with a Go API, a SvelteKit frontend, and PostgreSQL.

The project currently delivers:

- authenticated workflow management
- a block-based workout editor
- workflow versioning
- official templates with async clone jobs
- a persistent workout player for section-based execution

The workout player now creates persistent workout sessions and set logs in the backend, while still keeping local browser state for in-progress UX.

## Stack

- Backend: Go, Fiber, pgx/pgxpool, JWT, bcrypt, slog
- Frontend: SvelteKit (Svelte 5), TypeScript, Tailwind
- Database: PostgreSQL 16
- Dev environment: Docker Compose

## Current Product Surface

### Implemented

- Auth: register, login, logout
- Node types API
- Workflow CRUD
- Workflow version history
- Block editor with `section`, `exercise`, `linear_progression`, `wave`, `repeat`, `rest`, and `exercise_timed`
- Templates catalog
- Template cloning with clone-job polling
- Workout player V1
- Workout player 5.5 local runtime
- Workout sessions and set logging
- Session reliability hardening

### Workout player 6 / 6.5

The player already supports:

- choosing a section to execute
- persistent workout session creation
- persistent set / round logging
- local runtime state for in-progress UX
- local notes per block
- actual reps / load / RPE entry
- timers and intra-set rest
- session completion summary
- workout history by workflow
- browser persistence via `localStorage`
- session resume / active-session reuse
- duplicate log protection for repeated clicks / retries

The player does not yet support:

- progression state
- autoregulation

## Running locally

### With Docker

```bash
docker compose -f docker-compose.dev.yml up --build
```

Services:

- Web: `http://localhost:3000`
- API: `http://localhost:8080`
- Postgres: `localhost:5432`

Health check:

```bash
curl http://localhost:8080/health
```

### Without Docker

API environment lives in `api/.env` or shell env vars:

```env
DATABASE_URL=postgres://rep:rep@localhost:5432/repengine
JWT_SECRET=your-secret-key-here
```

Run the API:

```bash
cd api
go run ./cmd/server
```

Run the frontend:

```bash
cd web
npm install
npm run dev
```

## Available API

### Auth

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`

### Node Types

- `GET /node-types`
- `GET /node-types/:slug`

### Workflows

- `GET /workflows`
- `POST /workflows`
- `GET /workflows/:id`
- `PUT /workflows/:id`
- `DELETE /workflows/:id`
- `POST /workflows/:id/versions`
- `GET /workflows/:id/versions`
- `GET /workflows/:id/sessions`
- `POST /workflows/:id/sessions`

### Workout Sessions

- `GET /workout-sessions/:id`
- `POST /workout-sessions/:id/logs`
- `POST /workout-sessions/:id/complete`

### Templates

- `GET /templates`
- `GET /templates/:id`
- `POST /templates/:id/clone`

### Clone Jobs

- `GET /clone-jobs/:id`

## Validation

### Backend tests

From `api/`:

```bash
go test ./...
```

Integration tests require a reachable PostgreSQL database.
If `DATABASE_URL` is not exported, the tests attempt to load `api/.env`.

### Frontend checks

From `web/`:

```bash
npm run check
```

### Manual validation

Manual validation of the workout session flow is still pending.

Recommended quick pass:

- start a section and confirm a session is created
- log a few sets and verify they persist
- reload during the workout and confirm the active session resumes
- finish the section and confirm the session becomes `completed`
- verify the session appears in workflow history

### Workflow update benchmark

From `api/`:

```bash
export BENCH_TOKEN='YOUR_JWT_TOKEN'
go run ./cmd/bench_put_workflow
```

Default benchmark settings:

- `BENCH_RUNS=80`
- `BENCH_WARMUP=5`

Latest local result on `2026-05-02`:

- runs: `80`
- warmup: `5`
- failures: `0`
- avg: `4.10ms`
- p50: `4.01ms`
- p95: `4.45ms`
- max: `6.10ms`

Status: `PASS` (`p95 < 200ms`)

## Status

### Completed

- Sprint 0: foundation
- Sprint 1: auth
- Sprint 1.5: API quality foundation
- Sprint 2: node types API
- Sprint 3: workflows CRUD, pagination, versioning
- Sprint 4: block editor frontend
- Sprint 5: templates and player V1
- Sprint 5.5: local-first player runtime polish
- Sprint 6: persistent workout sessions and set logging
- Sprint 6.5: session reliability and log integrity

### Not completed yet

- Sprint 7: autoregulation and progression state
- Sprint 8: deploy hardening

## Important Notes

- SQL migration files exist in `api/migrations/`, but the app currently boots schema through `api/internal/db/db.go`.
- Session hardening currently includes active-session reuse, deduplicated set logging, and migration locking.
- The repo now contains both the Sprint 6 session API and the Sprint 6.5 hardening migration in `api/migrations/010_harden_workout_sessions_and_logs.sql`.
- The current Docker setup is development-oriented: `docker-compose.dev.yml`, `api/Dockerfile`, and `web/Dockerfile`.
