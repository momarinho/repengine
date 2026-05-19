# Contributing to RepEngine

## Scope

Keep changes focused. A pull request should usually do one thing:

- one bug fix
- one feature slice
- one refactor with no behavior change
- one documentation or CI change

Large cross-cutting changes should be split into smaller PRs when practical.

## Local Setup

### Backend

```bash
cd api
CGO_ENABLED=0 go test ./...
CGO_ENABLED=0 go build ./cmd/server
```

### Frontend

```bash
cd web
npm ci
npm run check
npm run build
```

### Full stack

```bash
docker compose -f docker-compose.dev.yml up --build
```

## Branch Naming

Use short descriptive branch names:

- `feature/<topic>`
- `fix/<topic>`
- `chore/<topic>`
- `docs/<topic>`

Examples:

- `feature/workflow-restore`
- `fix/player-timer`
- `chore/ci-docker-publish`

## Pull Request Rules

Before opening a PR:

- run backend tests locally
- run frontend checks locally
- run frontend production build locally when touching `web/`
- update `README.md` when product surface or workflow changes
- update `openapi/openapi.yaml` when request/response contracts change
- add a new SQL migration instead of editing an already-applied migration

PRs should include:

- a clear summary of the user-facing or operational change
- notes about risk, migration impact, or rollout concerns when relevant
- screenshots or short recordings for meaningful UI changes

## Database Changes

For schema changes:

- add a new numbered file under `api/migrations/`
- do not rewrite old migration history
- make migrations safe for fresh boot and upgrade paths
- verify the boot path still succeeds with the migration smoke test

## API Changes

If you change API behavior:

- keep handlers, services, and repositories aligned
- preserve backward compatibility unless the change is intentionally breaking
- update `openapi/openapi.yaml`

## Branch Protection Policy

Recommended repository settings for `main`:

- require pull requests before merging
- require the `CI` workflow to pass
- require the `Docker` workflow to pass when image publishing is enabled
- disallow direct pushes
- require linear history or squash merges

These settings are enforced in GitHub repository settings, not from this file.

## Review Expectations

Reviewers should focus on:

- correctness and regression risk
- migration and deploy safety
- API contract changes
- missing tests or missing documentation

## Commit Messages

Prefer concise conventional-style summaries:

- `feat: add workflow history page`
- `fix: prevent false positive migration smoke checks`
- `docs: document branch protection policy`

## Security

Do not commit:

- production secrets
- real `.env` files
- credentials in workflow YAML

Use GitHub secrets or environment-scoped secrets for publish and deploy workflows.
