# RepEngine

[![CI](https://github.com/momarinho/repengine/actions/workflows/ci.yml/badge.svg)](https://github.com/momarinho/repengine/actions/workflows/ci.yml)
[![Docker](https://github.com/momarinho/repengine/actions/workflows/docker.yml/badge.svg)](https://github.com/momarinho/repengine/actions/workflows/docker.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**RepEngine** is a high-performance, full-stack workout routine builder and player. It features a custom block-based editor, asynchronous templates cloning, real-time training execution tracking, and automatic progression/autoregulation recommendations based on logged set history (RPE/RIR).

Designed as a modern local-first-friendly SaaS web application, it bridges the gap between complex training block configurations and frictionless physical execution in the gym.

---

## 🏗️ System Architecture

```mermaid
graph TD
    Client[SvelteKit Client] -- REST / Auth Cookie --> API[Go Fiber API]
    API -- pgxpool --> DB[(PostgreSQL 16)]
    API -- Background Worker --> Queue[Clone Jobs Engine]
    Queue -- Async Clone --> DB
```

---

## 🚀 Key Engineering & Architecture Showcases

This project is built using production-grade patterns, focusing on security, concurrency safety, data integrity, and high performance.

### 🛡️ 1. Concurrency & Data Integrity
*   **Optimistic Concurrency Control**: Edit conflicts in the block editor are prevented using timestamp comparisons (`updated_at`). If two editors update the same routine concurrently, the API rejects the slower request with a `409 Conflict` status, returning the server's current timestamp to allow client-side reconciliation.
*   **PostgreSQL Advisory Locks**: Schema migrations are applied automatically at boot via an embedded file system (`go:embed`). Execution is serialized across multiple application instances using transactional advisory locks to prevent concurrent schema corruption during rolling deployments.
*   **Relational Hardening**: Tight database schema constraints (`CHECK` blocks, cascading foreign keys, unified numeric metrics) maintain raw entry history while computing clean, normalized columns for progression logic.

### 🔒 2. Security & Hardening
*   **Secure Authentication**: Custom stateless JWT authentication with issuer/audience claims validation, secure-only cookies, token-revocation storage upon logout, and brute-force protection through rate limiters on registration/login endpoints.
*   **Least Privilege Execution**: Final production Docker containers drop root privileges and run under a minimal, dedicated `appuser` (using Alpine Linux), minimizing attack surfaces in host environments.

### ⚡ 3. Performance & Resource Optimization
*   **Ultra-low Latency**: Powered by Go Fiber and `pgxpool`, the API services workflow lookups and modifications under **~4ms** average latency (validated via local benchmarks of 80 runs).
*   **Thread-safe Process Cache**: Static node type schemas are parsed once at startup and stored in a thread-safe local cache, eliminating database overhead for read-heavy schema validations.
*   **Multi-Stage Builds**: Docker images utilize multi-stage compilations to keep final runtime packages under 25MB (Go API) and 90MB (SvelteKit Runner), caching intermediate dependencies optimally.

---

## 🛠️ Tech Stack

*   **Backend**: Go (v1.25), Fiber framework, `pgx/pgxpool` (native PostgreSQL driver), JWT, `slog` (structured logging), Prometheus metrics.
*   **Frontend**: SvelteKit (Svelte 5 runes), TypeScript, TailwindCSS, `localStorage` local runtime state.
*   **Database**: PostgreSQL 16.
*   **CI/CD & DevOps**: GitHub Actions (Linting, Tests, Docker Build & Push), Docker Compose, Nginx (TLS Termination).

---

## 🎮 Current Feature Surface

### Implemented
*   **Block-Based Editor**: Contextual block insertion supporting linear progression, wave loading, repeats, rest intervals, and timed exercises.
*   **Active Workout Player**: Real-time section execution, interactive timer/rest tracker, and set-by-set input logging (Load, Reps, RPE, RIR).
*   **Smart Progression Suggestions**: Real-time suggestion engine adjusting target loads/reps for linear and wave progression nodes based on completed set difficulty (Sprint 7).
*   **Version History & Restore**: Automatic serialization of workflow snapshots with restore capabilities and rollback mechanisms (Sprint 14).
*   **Account Settings**: Password resets, email/profile updates, and complete session invalidation on credential updates.

### Roadmap & Planned Features
*   **Sprint 15.5 — Cloud Infrastructure**: Managed database integration (OCI/AWS RDS), private networks, secret management, and remote migrations runbook.
*   **Sprint 16 — Observability**: Grafana dashboards, Nginx rate-limiting headers, CSP enforcement, and auto-TLS certificates.
*   **Sprint 17 — Offline First & PWA**: Service Workers offline support, background set logging sync, and client undo/redo history stack.

---

## 🏃 Running Locally

### With Docker (Recommended)

Start the entire stack (Database, API, and Web App):

```bash
docker compose -f docker-compose.dev.yml up --build
```

*   **Web App**: [http://localhost:3000](http://localhost:3000)
*   **API Service**: [http://localhost:8080](http://localhost:8080)
*   **API Healthcheck**: `curl http://localhost:8080/health`

### Without Docker

#### Prerequisites
*   Go 1.25+
*   Node.js 20+
*   Running PostgreSQL instance

#### 1. Setup API
Create `api/.env`:
```env
DATABASE_URL=postgres://rep:rep@localhost:5432/repengine
JWT_SECRET=your-development-secret-key
```

Run the backend server:
```bash
cd api
go run ./cmd/server
```

#### 2. Setup Frontend
Run the SvelteKit development server:
```bash
cd web
npm install
npm run dev
```

---

## 🧪 Validation & Tests

### Backend Tests
Execute unit tests from `api/`:
```bash
CGO_ENABLED=0 go test ./...
```
*Note: Integration tests require a live database connection string specified in `DATABASE_URL`.*

### Frontend Checks
Validate TypeScript and Svelte syntax from `web/`:
```bash
npm run check
```

### Performance Benchmark
Run the workflow update benchmark from `api/` (requires a valid JWT):
```bash
export BENCH_TOKEN='YOUR_JWT_TOKEN'
go run ./cmd/bench_put_workflow
```

Latest local benchmark status: **PASS** (Avg: **4.10ms** / p95: **4.45ms**).

---

## 📄 License

This project is open-source software licensed under the [MIT License](LICENSE).
