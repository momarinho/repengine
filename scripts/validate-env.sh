#!/usr/bin/env bash
# =============================================================================
# validate-env.sh — Validate required environment variables before deploying
#
# Usage:
#   ./scripts/validate-env.sh [--env prod|staging|dev]
#
# Options:
#   --env   Target environment (default: prod)
#
# Behavior:
#   - Loads .env from the project root if present
#   - Checks all required variables for the given environment
#   - Prints a colored pass/fail for each variable
#   - Exits 1 if any required variable is missing
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
# Defaults
# ---------------------------------------------------------------------------
DEPLOY_ENV="prod"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      DEPLOY_ENV="${2:-}"
      if [[ -z "$DEPLOY_ENV" ]]; then
        echo -e "${RED}ERROR:${NC} --env requires an argument (prod|staging|dev)" >&2
        exit 1
      fi
      shift 2
      ;;
    --help|-h)
      sed -n '2,14p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo -e "${RED}ERROR:${NC} Unknown argument: $1" >&2
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
    echo -e "${RED}ERROR:${NC} Invalid environment '${DEPLOY_ENV}'. Must be prod, staging, or dev." >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Load .env file if present (from project root or current directory)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  echo -e "${CYAN}INFO:${NC}  Loading environment from ${PROJECT_ROOT}/.env"
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
elif [[ -f ".env" ]]; then
  echo -e "${CYAN}INFO:${NC}  Loading environment from ./.env"
  set -a
  # shellcheck source=/dev/null
  source ".env"
  set +a
fi

# ---------------------------------------------------------------------------
# Required variables per environment
# ---------------------------------------------------------------------------
declare -a REQUIRED_VARS

case "$DEPLOY_ENV" in
  prod)
    REQUIRED_VARS=(
      "DATABASE_URL"
      "JWT_SECRET"
      "POSTGRES_USER"
      "POSTGRES_PASSWORD"
      "POSTGRES_DB"
      "CORS_ORIGINS"
      "VERSION"
      "REGISTRY"
    )
    ;;
  staging)
    REQUIRED_VARS=(
      "DATABASE_URL"
      "JWT_SECRET"
      "POSTGRES_USER"
      "POSTGRES_PASSWORD"
      "POSTGRES_DB"
      "VERSION"
    )
    ;;
  dev)
    REQUIRED_VARS=(
      "DATABASE_URL"
    )
    ;;
esac

# ---------------------------------------------------------------------------
# Validation loop
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}Validating environment variables for: ${CYAN}${DEPLOY_ENV}${NC}"
echo -e "$(printf '%.0s─' {1..50})"

MISSING=()

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -n "${!VAR:-}" ]]; then
    # Mask secrets in output — show first 4 chars then asterisks
    VALUE="${!VAR}"
    case "$VAR" in
      *PASSWORD*|*SECRET*|*TOKEN*|DATABASE_URL)
        DISPLAY="${VALUE:0:4}$(printf '%0.s*' {1..8})"
        ;;
      *)
        DISPLAY="$VALUE"
        ;;
    esac
    echo -e "  ${GREEN}✓${NC} ${VAR} = ${DISPLAY}"
  else
    echo -e "  ${RED}✗${NC} ${VAR} ${RED}(missing)${NC}"
    MISSING+=("$VAR")
  fi
done

echo -e "$(printf '%.0s─' {1..50})"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL="${#REQUIRED_VARS[@]}"
MISSING_COUNT="${#MISSING[@]}"
PRESENT_COUNT=$(( TOTAL - MISSING_COUNT ))

echo ""
if [[ "$MISSING_COUNT" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✓ All ${TOTAL} required variable(s) are set for '${DEPLOY_ENV}'.${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}✗ ${MISSING_COUNT} of ${TOTAL} variable(s) are missing for '${DEPLOY_ENV}':${NC}"
  for VAR in "${MISSING[@]}"; do
    echo -e "    ${RED}•${NC} ${VAR}"
  done
  echo ""
  echo -e "${YELLOW}HINT:${NC} Copy .env.example to .env and fill in the missing values:"
  echo -e "       cp .env.example .env"
  echo ""
  exit 1
fi
