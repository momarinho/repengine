# RepEngine

RepEngine is a full-stack training routine builder with a Go API, a SvelteKit frontend, and PostgreSQL.

The project currently delivers:

- authenticated workflow management
- a block-based workout editor
- workflow versioning
- official templates with async clone jobs
- a persistent workout player for section-based execution
- basic progression state and autoregulation suggestions
- schema hardening for workout/session/progression data
- account settings, password reset, and workflow history

The workout player now creates persistent workout sessions and set logs in the backend, keeps local browser state for in-progress UX, and derives simple next-session progression suggestions from real logs.

## Stack

- Backend: Go, Fiber, pgx/pgxpool, JWT, bcrypt, slog
- Frontend: SvelteKit (Svelte 5), TypeScript, Tailwind
- Database: PostgreSQL 16
- Dev environment: Docker Compose

## Current Product Surface

### Implemented

- Auth: register, login, logout
- Auth account management: current account read/update/delete and password reset flow
- Auth security hardening: secure cookies by environment, logout token invalidation, CORS, auth rate limiting, register validation, JWT issuer/audience claims
- Node types API
- Workflow CRUD
- Workflow version history
- Block editor with `section`, `exercise`, `linear_progression`, `wave`, `repeat`, `rest`, and `exercise_timed`
- Contextual block insertion in the editor (start of routine, after selected, below any block)
- Templates catalog
- Template cloning with clone-job polling
- Workout player V1
- Workout player 5.5 local runtime
- Workout sessions and set logging
- Session reliability hardening
- Progression states and simple autoregulation
- Schema hardening with constraints, FK cleanup, and canonical numeric metrics
- Workout history, basic volume analytics, and post-session log editing
- Workflow version restore

### Workout player 6 / 6.5 / 7

The player already supports:

- choosing a section to execute
- persistent workout session creation
- persistent set / round logging
- local runtime state for in-progress UX
- local notes per block
- actual reps / load / RPE / RIR entry
- timers and intra-set rest
- session completion summary
- workout history by workflow
- browser persistence via `localStorage`
- session resume / active-session reuse
- active session abandonment
- duplicate log protection for repeated clicks / retries
- progression state by workflow block
- simple next-session suggestions for `linear_progression`
- simple week / intensity adjustment suggestions for `wave`
- simple skill progression suggestions for skill-like `exercise` / `exercise_timed` blocks

The player still does not support:

- complex autoregulation
- sophisticated training-max logic
- advanced analytics / charts
- mobile / offline sync

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
- `GET /auth/me`
- `PUT /auth/me`
- `DELETE /auth/me`
- `POST /auth/password-reset/request`
- `POST /auth/password-reset/confirm`

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
- `POST /workflows/:id/versions/:versionId/restore`
- `GET /workflows/:id/sessions`
- `POST /workflows/:id/sessions`
- `GET /workflows/:id/progression-states`
- `GET /workflows/:id/analytics`

### Workout Sessions

- `GET /workout-sessions/:id`
- `POST /workout-sessions/:id/logs`
- `PUT /workout-sessions/:id/logs/:logId`
- `POST /workout-sessions/:id/complete`
- `POST /workout-sessions/:id/abandon`

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

If your local Go toolchain defaults to `cgo` and no C compiler is installed, run:

```bash
CGO_ENABLED=0 go test ./...
```

Integration tests require a reachable PostgreSQL database.
If `DATABASE_URL` is not exported, the tests attempt to load `api/.env`.

### Frontend checks

From `web/`:

```bash
npm run check
```

### Manual validation

Recommended Sprint 14 validation:

- start a section and confirm a session is created
- log a few sets with `actual reps`, `actual load`, `actual RPE`, and `actual RIR`
- reload during the workout and confirm the active session resumes
- finish the section and confirm the session becomes `completed`
- verify the session appears in workflow history
- re-open the same workflow and confirm progression suggestions now appear on the relevant blocks
- for `linear_progression`, confirm the suggested next load changes after an easy vs hard session
- for `wave`, confirm the suggested week or intensity offset changes after an easy vs hard session
- for skill-like blocks, confirm the suggestion can stay / advance / regress based on logged effort and reps
- confirm auth register/login/logout still work and logout invalidates the previous token
- create workflow versions back-to-back and confirm version numbers remain sequential
- manually expire or revoke the auth token and confirm protected pages redirect back to `/login`
- verify the dashboard `All / Private / Public` filter changes the visible routines
- open the editor, make a change, confirm the UI shows unsaved state before autosave completes, and confirm manual save flushes immediately
- resume a player session after reload and confirm timer/rest state resumes from persisted state
- log in as a second user on the same browser profile and confirm player local persistence does not leak across users
- open workflow history and confirm recent sessions, set logs, and basic analytics render
- edit a persisted set log and confirm the updated values remain visible after reload
- abandon an active session from the player and confirm it appears as `abandoned` in history
- restore an older workflow version from the editor history tab and confirm blocks/title/settings revert to the snapshot
- open `/settings`, change email or password, and confirm the current session is invalidated
- request a password reset from `/forgot-password` and complete it from `/reset-password`

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
- Sprint 7: autoregulation and progression state
- Sprint 8: deploy hardening
- Sprint 9: critical hotfix
- Sprint 9.5: block editor insertion UX
- Sprint 10: security hardening
- Sprint 11: schema hardening
- Sprint 12: API quality and tests
- Sprint 13: frontend bug fixes
- Sprint 14: account and history

### Not completed yet

Features not yet started:

- exercise autocomplete / search
- undo/redo in the block editor
- filter workflows by category (UI exists, backend field does not)
- PWA / offline support / background sync for set logs
- dark/light mode toggle (CSS tokens defined, toggle not wired)
- complex autoregulation (training-max logic, readiness modeling)
- analytics and charts
- external database hosting for staging/production (for example OCI VM or managed PostgreSQL)

## Roadmap

| Sprint | Theme | Scope |
|--------|-------|-------|
| **15** | **CI/CD** | GitHub Actions (lint, test, build, push), migration testing on fresh DB, branch protection, `CONTRIBUTING.md`, `LICENSE`, OpenAPI spec |
| **15.5** | **Cloud Infrastructure** | External PostgreSQL host for staging/production (for example OCI VM or managed PostgreSQL), private networking, backup/restore, secret management, migration runbook |
| **16** | **Observability** | Prometheus alerting rules, `node_exporter`, `postgres_exporter`, Grafana dashboard JSON, nginx rate limiting, CSP header, TLS certificate automation |
| **17** | **Accessibility & PWA** | ARIA roles/labels, modal focus trap, keyboard drag-and-drop, undo/redo, Service Worker offline support, background sync |

## Tech Debt

Known issues that don't block current functionality but need to be addressed before scaling:

- **Raw fitness fields remain text-first.** User-facing fields like `actual_load`, `actual_rpe`, and `current_load` remain `VARCHAR(50)` to preserve entries such as `100 kg`, ranges, and mixed notation. Sprint 11 added canonical numeric companion columns for analytics, but a future pass may still normalize the wider data model.
- **No CI pipeline.** There are no automated build or test workflows. Broken changes can reach production silently. Sprint 15 addresses this.
- **Node types are still loaded as process-local cache.** This is fine for current scale, but cache invalidation and runtime refresh are still manual.

## Important Notes

- SQL migration files live in `api/migrations/`. At startup, `internal/db/migrations.go` reads and applies them in order using an embedded FS (`//go:embed *.sql`). Applied versions are tracked in a `schema_migrations` table with a Postgres advisory lock to prevent concurrent execution. Migration files may include a `-- Down` section for documentation; the runner automatically strips everything from that marker onwards so rollback SQL is never executed during boot.
- Session hardening includes active-session reuse, deduplicated set logging, and migration locking.
- Sprint 7 progression is intentionally simple: it is based on completed logs plus `RPE/RIR`, not on advanced readiness modeling.
- Sprint 8 introduced production Docker hardening: multi-stage Dockerfiles with non-root users, `docker-compose.prod.yml` and `docker-compose.staging.yml`, Nginx with TLS termination, Prometheus + Grafana, and operational scripts under `scripts/`.
- Sprint 9.5 improved block editor UX: new blocks can be inserted at the start of the routine, after the selected block, or directly below any existing block instead of always appending to the end.
- Sprint 10 hardened auth and API security with environment-aware secure cookies, logout-driven token invalidation, CORS policy enforcement, auth endpoint rate limiting, register input validation, and JWT issuer/audience claims.
- Sprint 11 hardened the schema with status/outcome/state `CHECK` constraints, missing FKs, targeted indexes, and canonical numeric columns alongside the existing raw text fitness fields.
- Sprint 12 moved auth into a dedicated service/repository layer, replaced handler package singletons with explicit dependency wiring, added handler-level Fiber tests, surfaced progression failures on session completion, and serialized workflow version creation to avoid duplicate version numbers.
- Sprint 13 fixed protected-route token validation in SvelteKit, restored the workflow versions GET proxy, corrected the dashboard filter, scoped player local persistence by user with migration from the legacy key, resumed persisted timer/rest state correctly, and improved autosave UI semantics in the editor.
- Sprint 14 added account settings, password reset tokens, workflow history and basic analytics pages, active-session abandonment, persisted set-log editing, and workflow version restore across the API and SvelteKit app.
- Planned infrastructure work keeps local development on Docker Compose while moving staging/production database hosting to dedicated cloud infrastructure such as an OCI VM or managed PostgreSQL.
- The progression state `block_key` format is `sectionTitle::nodeTypeSlug::exerciseName::occurrence`. Renaming a section will orphan its progression history — this is a known limitation tracked in the roadmap.
