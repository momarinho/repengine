#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Production deploy helper for repengine
#
# Usage:
#   ./scripts/deploy.sh [--env prod|staging] [--version VERSION] [--skip-backup]
#
# Options:
#   --env           Target environment (default: prod)
#   --version       Docker image version/tag to deploy
#                   (default: VERSION env var, or latest git tag, or "dev")
#   --skip-backup   Skip the pre-deploy database backup
#
# Steps:
#   1. Validate environment variables via validate-env.sh
#   2. Take a pre-deploy database backup (unless --skip-backup)
#   3. Pull latest Docker images
#   4. Deploy with docker compose up -d --remove-orphans
#   5. Poll the /health endpoint until the service is healthy
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
step()    { echo -e "\n${BOLD}[STEP]${NC}    $*"; }

# ---------------------------------------------------------------------------
# Locate project root
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Load .env if present (before argument defaults that reference env vars)
# ---------------------------------------------------------------------------
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
elif [[ -f ".env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source ".env"
  set +a
fi

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DEPLOY_ENV="prod"
SKIP_BACKUP=false

# Version: prefer VERSION env var, then latest git tag, else "dev"
DEFAULT_VERSION="${VERSION:-}"
if [[ -z "$DEFAULT_VERSION" ]]; then
  DEFAULT_VERSION="$(git -C "${PROJECT_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "dev")"
fi
VERSION="${DEFAULT_VERSION}"

# Health-check settings
HEALTH_URL="http://localhost:8080/health"
HEALTH_TIMEOUT=60   # seconds total
HEALTH_INTERVAL=5   # seconds between polls

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      DEPLOY_ENV="${2:-}"
      if [[ -z "$DEPLOY_ENV" ]]; then
        error "--env requires an argument (prod|staging)"
        exit 1
      fi
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      if [[ -z "$VERSION" ]]; then
        error "--version requires an argument"
        exit 1
      fi
      shift 2
      ;;
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --help|-h)
      sed -n '2,18p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      echo "Usage: $0 [--env prod|staging] [--version VERSION] [--skip-backup]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate env argument
# ---------------------------------------------------------------------------
case "$DEPLOY_ENV" in
  prod|staging) ;;
  *)
    error "Invalid environment '${DEPLOY_ENV}'. Must be prod or staging."
    exit 1
    ;;
esac

COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.${DEPLOY_ENV}.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  error "Compose file not found: ${COMPOSE_FILE}"
  error "Run this from the project root, or ensure the file has been created."
  exit 1
fi

# ---------------------------------------------------------------------------
# Error trap — print rollback guidance on unexpected failure
# ---------------------------------------------------------------------------
on_error() {
  local EXIT_CODE=$?
  echo ""
  error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  error "Deployment FAILED (exit code ${EXIT_CODE})."
  error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  warn  "To rollback, re-run with the previous VERSION tag:"
  echo  "  VERSION=<previous-tag> ./scripts/deploy.sh --env ${DEPLOY_ENV} --skip-backup"
  warn  "To view recent logs:"
  echo  "  docker compose -f ${COMPOSE_FILE} logs --tail=50 api"
  echo ""
}
trap on_error ERR

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          repengine — Deployment Script                ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
info "Environment : ${DEPLOY_ENV}"
info "Version     : ${VERSION}"
info "Compose     : ${COMPOSE_FILE}"
info "Skip backup : ${SKIP_BACKUP}"
echo ""

# Export VERSION so docker compose can use it in image tags
export VERSION

# ---------------------------------------------------------------------------
# Step 1: Validate environment variables
# ---------------------------------------------------------------------------
step "1/5  Validating environment variables..."
"${SCRIPT_DIR}/validate-env.sh" --env "${DEPLOY_ENV}"

# ---------------------------------------------------------------------------
# Step 2: Pre-deploy database backup
# ---------------------------------------------------------------------------
if [[ "$SKIP_BACKUP" == false ]]; then
  step "2/5  Running pre-deploy database backup..."
  "${SCRIPT_DIR}/backup.sh"
else
  warn "Step 2/5  Backup skipped (--skip-backup flag set)."
fi

# ---------------------------------------------------------------------------
# Step 3: Pull latest images
# ---------------------------------------------------------------------------
step "3/5  Pulling latest Docker images (version: ${VERSION})..."
docker compose -f "$COMPOSE_FILE" pull
success "Images pulled."

# ---------------------------------------------------------------------------
# Step 4: Deploy
# ---------------------------------------------------------------------------
step "4/5  Deploying services with zero-downtime restart..."
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans
success "Containers started."

# ---------------------------------------------------------------------------
# Step 5: Health check
# ---------------------------------------------------------------------------
step "5/5  Waiting for health check at ${HEALTH_URL} ..."

ELAPSED=0
HEALTHY=false

while [[ $ELAPSED -lt $HEALTH_TIMEOUT ]]; do
  HTTP_STATUS="$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "${HEALTH_URL}" 2>/dev/null || echo "000")"
  if [[ "$HTTP_STATUS" == "200" ]]; then
    HEALTHY=true
    break
  fi
  info "  Health check returned HTTP ${HTTP_STATUS} — retrying in ${HEALTH_INTERVAL}s (${ELAPSED}/${HEALTH_TIMEOUT}s elapsed)"
  sleep "$HEALTH_INTERVAL"
  ELAPSED=$(( ELAPSED + HEALTH_INTERVAL ))
done

if [[ "$HEALTHY" == true ]]; then
  trap - ERR
  echo ""
  echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║   ✓  Deployment complete! repengine is healthy.       ║${NC}"
  echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
  echo ""
  info "Environment : ${DEPLOY_ENV}"
  info "Version     : ${VERSION}"
  info "Health      : ${HEALTH_URL} → HTTP 200"
  echo ""
else
  error "Health check failed after ${HEALTH_TIMEOUT}s. Dumping recent API logs:"
  echo ""
  docker compose -f "$COMPOSE_FILE" logs --tail=50 api
  echo ""
  error "Deployment appears unhealthy. Investigate logs above."
  exit 1
fi
