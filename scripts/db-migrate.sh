#!/usr/bin/env bash
# =============================================================================
# db-migrate.sh — Manually trigger database migrations for repengine
#
# Usage:
#   ./scripts/db-migrate.sh [--env prod|staging|dev]
#
# Options:
#   --env   Target environment (default: prod)
#
# Behavior:
#   Migrations in repengine run automatically at API startup.
#   This script restarts the API container to trigger them on demand.
#   It then tails the startup logs briefly so you can confirm the result.
#
# Environment variables:
#   ENV   — Shorthand for the target environment (alternative to --env)
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
info()    { echo -e "${CYAN}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC}   $*" >&2; }

# ---------------------------------------------------------------------------
# Locate project root
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Load .env if present
# ---------------------------------------------------------------------------
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  info "Loading environment from ${PROJECT_ROOT}/.env"
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
elif [[ -f ".env" ]]; then
  info "Loading environment from ./.env"
  set -a
  # shellcheck source=/dev/null
  source ".env"
  set +a
fi

# ---------------------------------------------------------------------------
# Defaults — respect ENV env var as shorthand
# ---------------------------------------------------------------------------
DEPLOY_ENV="${ENV:-prod}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      DEPLOY_ENV="${2:-}"
      if [[ -z "$DEPLOY_ENV" ]]; then
        error "--env requires an argument (prod|staging|dev)"
        exit 1
      fi
      shift 2
      ;;
    --help|-h)
      sed -n '2,18p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      echo "Usage: $0 [--env prod|staging|dev]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate env argument
# ---------------------------------------------------------------------------
case "$DEPLOY_ENV" in
  prod|staging|dev) ;;
  *)
    error "Invalid environment '${DEPLOY_ENV}'. Must be prod, staging, or dev."
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Resolve compose file
# ---------------------------------------------------------------------------
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.${DEPLOY_ENV}.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  error "Compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Check that the api container is actually running
# ---------------------------------------------------------------------------
if ! docker compose -f "$COMPOSE_FILE" ps api 2>/dev/null | grep -q "running\|Up"; then
  warn "The 'api' service does not appear to be running."
  warn "Starting it now (migrations will run on startup)..."
  docker compose -f "$COMPOSE_FILE" up -d api
else
  # ---------------------------------------------------------------------------
  # Restart the API container — migrations run automatically on startup
  # ---------------------------------------------------------------------------
  info "Environment : ${DEPLOY_ENV}"
  info "Compose     : ${COMPOSE_FILE}"
  echo ""
  info "Restarting the 'api' container to trigger migrations..."
  docker compose -f "$COMPOSE_FILE" restart api
fi

# ---------------------------------------------------------------------------
# Tail logs briefly to show migration output
# ---------------------------------------------------------------------------
echo ""
info "Tailing API startup logs (10s)..."
echo -e "$(printf '%.0s─' {1..60})"
timeout 10 docker compose -f "$COMPOSE_FILE" logs -f api 2>/dev/null || true
echo -e "$(printf '%.0s─' {1..60})"
echo ""

# ---------------------------------------------------------------------------
# Final status
# ---------------------------------------------------------------------------
API_STATUS="$(docker compose -f "$COMPOSE_FILE" ps api 2>/dev/null | tail -1)"
echo -e "${BOLD}Container status:${NC} ${API_STATUS}"
echo ""

if docker compose -f "$COMPOSE_FILE" ps api 2>/dev/null | grep -q "running\|Up"; then
  success "Migration restart complete. API container is running."
  echo ""
  info "To view full logs:"
  echo "  docker compose -f ${COMPOSE_FILE} logs api"
else
  error "API container is not running after restart. Check logs:"
  echo "  docker compose -f ${COMPOSE_FILE} logs api"
  exit 1
fi
