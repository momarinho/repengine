#!/usr/bin/env bash
# =============================================================================
# backup.sh — PostgreSQL backup script for repengine
#
# Usage:
#   ./scripts/backup.sh
#
# Environment variables (can be set in .env):
#   POSTGRES_USER       — Database user
#   POSTGRES_PASSWORD   — Database password
#   POSTGRES_DB         — Database name
#   DATABASE_URL        — Full connection string (used to extract host)
#   BACKUP_DIR          — Local directory for backups (default: ./backups)
#   BACKUP_S3_BUCKET    — Optional S3 bucket for remote upload
#
# Behavior:
#   - Creates a timestamped gzip-compressed SQL dump
#   - Deletes local backups older than 30 days
#   - Optionally uploads to S3 if BACKUP_S3_BUCKET is set
#   - Uses docker compose exec when the db container is running,
#     falls back to a direct pg_dump otherwise
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
# Locate project root (one level up from this script)
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
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/backups}"
BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-}"
DATABASE_URL="${DATABASE_URL:-}"

if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_PASSWORD" || -z "$POSTGRES_DB" ]]; then
  error "POSTGRES_USER, POSTGRES_PASSWORD, and POSTGRES_DB must all be set."
  error "Set them directly or via a .env file."
  exit 1
fi

# ---------------------------------------------------------------------------
# Extract DB host from DATABASE_URL (if provided), else fallback to localhost
# ---------------------------------------------------------------------------
if [[ -n "$DATABASE_URL" ]]; then
  # Pattern: postgres://user:pass@host:port/db  — grab the host segment
  DB_HOST="$(echo "$DATABASE_URL" | grep -oP '(?<=@)[^:/]+'  2>/dev/null || true)"
  DB_HOST="${DB_HOST:-localhost}"
else
  DB_HOST="localhost"
fi

info "Database host resolved to: ${DB_HOST}"

# ---------------------------------------------------------------------------
# Prepare backup directory and filename
# ---------------------------------------------------------------------------
mkdir -p "${BACKUP_DIR}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/repengine_${TIMESTAMP}.sql.gz"

info "Backup target : ${BACKUP_FILE}"
info "Database      : ${POSTGRES_DB} @ ${DB_HOST} (user: ${POSTGRES_USER})"

# ---------------------------------------------------------------------------
# Determine backup method: docker compose exec vs direct pg_dump
# ---------------------------------------------------------------------------
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.prod.yml"

run_backup() {
  # Prefer docker compose exec if the compose file exists and the db service is running
  if [[ -f "$COMPOSE_FILE" ]] && docker compose -f "$COMPOSE_FILE" ps db 2>/dev/null | grep -q "running\|Up"; then
    info "Using docker compose exec (db container is running)"
    docker compose -f "$COMPOSE_FILE" exec -T db \
      pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" \
      | gzip > "${BACKUP_FILE}"
  else
    info "Using direct pg_dump (host: ${DB_HOST})"
    if ! command -v pg_dump &>/dev/null; then
      error "pg_dump not found and db container is not running. Cannot create backup."
      exit 1
    fi
    PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
      -h "${DB_HOST}" \
      -U "${POSTGRES_USER}" \
      "${POSTGRES_DB}" \
      | gzip > "${BACKUP_FILE}"
  fi
}

# ---------------------------------------------------------------------------
# Run backup with error handling
# ---------------------------------------------------------------------------
info "Starting backup..."
if run_backup; then
  BACKUP_SIZE="$(du -sh "${BACKUP_FILE}" | cut -f1)"
  success "Backup created successfully: ${BACKUP_FILE} (${BACKUP_SIZE})"
else
  error "Backup failed. Removing partial file if it exists."
  rm -f "${BACKUP_FILE}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Retention: remove backups older than 30 days
# ---------------------------------------------------------------------------
info "Applying retention policy: deleting backups older than 30 days from ${BACKUP_DIR}"
DELETED_COUNT=0
while IFS= read -r old_file; do
  rm -f "$old_file"
  warn "  Deleted old backup: $(basename "$old_file")"
  DELETED_COUNT=$(( DELETED_COUNT + 1 ))
done < <(find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +30 2>/dev/null || true)

if [[ "$DELETED_COUNT" -eq 0 ]]; then
  info "No old backups to remove."
else
  info "Removed ${DELETED_COUNT} backup(s) older than 30 days."
fi

# ---------------------------------------------------------------------------
# Optional S3 upload
# ---------------------------------------------------------------------------
if [[ -n "$BACKUP_S3_BUCKET" ]]; then
  info "Uploading backup to S3: s3://${BACKUP_S3_BUCKET}/backups/"
  if ! command -v aws &>/dev/null; then
    warn "aws CLI not found — skipping S3 upload."
  else
    if aws s3 cp "${BACKUP_FILE}" "s3://${BACKUP_S3_BUCKET}/backups/"; then
      success "Backup uploaded to s3://${BACKUP_S3_BUCKET}/backups/$(basename "${BACKUP_FILE}")"
    else
      error "S3 upload failed. Local backup is still available at ${BACKUP_FILE}"
      exit 1
    fi
  fi
else
  info "BACKUP_S3_BUCKET not set — skipping S3 upload."
fi

echo ""
success "${BOLD}Backup complete.${NC}"
echo -e "  File : ${BACKUP_FILE}"
