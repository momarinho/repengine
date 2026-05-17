#!/usr/bin/env bash
# =============================================================================
# restore.sh — PostgreSQL restore script for repengine
#
# Usage:
#   ./scripts/restore.sh <path/to/backup.sql.gz> [--force]
#
# Arguments:
#   <backup-file>   Path to the .sql.gz backup file to restore (required)
#
# Options:
#   --force         Skip the confirmation prompt
#
# Environment variables (can be set in .env):
#   POSTGRES_USER       — Database user
#   POSTGRES_PASSWORD   — Database password
#   POSTGRES_DB         — Database name
#
# WARNING:
#   This script DROPS and RECREATES the target database.
#   All existing data will be permanently lost.
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
# Usage
# ---------------------------------------------------------------------------
usage() {
  echo ""
  echo -e "${BOLD}Usage:${NC} $0 <path/to/backup.sql.gz> [--force]"
  echo ""
  echo "  <backup-file>   Path to the .sql.gz file to restore (required)"
  echo "  --force         Skip the confirmation prompt"
  echo ""
  echo -e "${YELLOW}WARNING:${NC} This DROPS and RECREATES the database. All data will be lost."
  echo ""
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
BACKUP_FILE=""
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      error "Unknown option: $arg"
      usage
      exit 1
      ;;
    *)
      if [[ -z "$BACKUP_FILE" ]]; then
        BACKUP_FILE="$arg"
      else
        error "Unexpected argument: $arg"
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$BACKUP_FILE" ]]; then
  error "No backup file specified."
  usage
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  error "Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

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
# Resolve required variables
# ---------------------------------------------------------------------------
POSTGRES_USER="${POSTGRES_USER:-}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_DB="${POSTGRES_DB:-}"

if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_DB" ]]; then
  error "POSTGRES_USER and POSTGRES_DB must be set."
  exit 1
fi

COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.prod.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  error "Compose file not found: ${COMPOSE_FILE}"
  error "Ensure docker-compose.prod.yml exists in the project root."
  exit 1
fi

# ---------------------------------------------------------------------------
# Confirmation prompt
# ---------------------------------------------------------------------------
echo ""
echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}${BOLD}║                  ⚠  DESTRUCTIVE OPERATION ⚠             ║${NC}"
echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}WARNING:${NC} You are about to ${RED}DROP${NC} and ${RED}RECREATE${NC} the database:"
echo -e "  Database    : ${BOLD}${POSTGRES_DB}${NC}"
echo -e "  User        : ${BOLD}${POSTGRES_USER}${NC}"
echo -e "  Backup file : ${BOLD}${BACKUP_FILE}${NC}"
echo ""
echo -e "${RED}ALL EXISTING DATA WILL BE PERMANENTLY LOST.${NC}"
echo ""

if [[ "$FORCE" == false ]]; then
  read -r -p "Type 'yes' to confirm, anything else to abort: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    warn "Restore aborted by user."
    exit 0
  fi
else
  warn "--force flag set. Skipping confirmation."
fi

echo ""

# ---------------------------------------------------------------------------
# Error trap
# ---------------------------------------------------------------------------
on_error() {
  echo ""
  error "Restore FAILED at step: ${LAST_STEP:-unknown}"
  error "The database may be in an inconsistent state."
  error "Backup file is still available at: ${BACKUP_FILE}"
}
trap on_error ERR

# ---------------------------------------------------------------------------
# Step 1: Drop the existing database
# ---------------------------------------------------------------------------
LAST_STEP="DROP DATABASE"
info "Step 1/3: Dropping database '${POSTGRES_DB}'..."
docker compose -f "$COMPOSE_FILE" exec -T db \
  psql -U "${POSTGRES_USER}" -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};"
success "Database dropped."

# ---------------------------------------------------------------------------
# Step 2: Recreate the database
# ---------------------------------------------------------------------------
LAST_STEP="CREATE DATABASE"
info "Step 2/3: Creating database '${POSTGRES_DB}'..."
docker compose -f "$COMPOSE_FILE" exec -T db \
  psql -U "${POSTGRES_USER}" -c "CREATE DATABASE ${POSTGRES_DB};"
success "Database created."

# ---------------------------------------------------------------------------
# Step 3: Restore from backup
# ---------------------------------------------------------------------------
LAST_STEP="RESTORE FROM BACKUP"
BACKUP_SIZE="$(du -sh "${BACKUP_FILE}" | cut -f1)"
info "Step 3/3: Restoring from ${BACKUP_FILE} (${BACKUP_SIZE})..."
gunzip -c "${BACKUP_FILE}" \
  | docker compose -f "$COMPOSE_FILE" exec -T db \
      psql -U "${POSTGRES_USER}" "${POSTGRES_DB}"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
trap - ERR
echo ""
success "${BOLD}Restore complete.${NC}"
echo -e "  Database '${POSTGRES_DB}' has been restored from:"
echo -e "  ${BACKUP_FILE}"
echo ""
info "You may want to restart the API to re-run migrations:"
echo -e "  docker compose -f docker-compose.prod.yml restart api"
echo ""
