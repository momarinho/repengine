# RepEngine

A full-stack training routine builder powered by a **Go API**, **SvelteKit frontend**, and **PostgreSQL**.  
The current focus is a robust block editor, versioned workflows, and production-minded engineering foundations.

## Stack

- **Backend:** Go, Fiber, pgx/pgxpool, JWT, bcrypt, slog
- **Frontend:** SvelteKit (Svelte 5), TypeScript, Tailwind
- **Database:** PostgreSQL 16
- **Dev environment:** Docker Compose

## Running locally

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

## Backend Validation

### Automated tests

From `api/`:

```bash
go test ./...
```

Integration tests for transactional rollback require a reachable PostgreSQL database.
If `DATABASE_URL` is not exported, the tests attempt to load `api/.env`.

### Performance benchmark

From `api/`:

```bash
export BENCH_TOKEN='YOUR_JWT_TOKEN'
go run ./cmd/bench_put_workflow
```

Default benchmark settings:

- `BENCH_RUNS=80`
- `BENCH_WARMUP=5`

These defaults are chosen to stay below the API rate limit during a local run.

Latest local result on 2026-05-02:

- runs: 80
- warmup: 5
- failures: 0
- avg: 4.10ms
- p50: 4.01ms
- p95: 4.45ms
- max: 6.10ms

Status: PASS (`p95 < 200ms`)

## Current status

Completed:

- Sprint 0 (foundation)
- Sprint 1 (auth)
- Sprint 1.5 (API quality foundation)
- Sprint 2 (node types API)
- Sprint 3 (workflows CRUD + versioning + pagination)

In progress:

- Sprint 4 (Block Editor frontend)
