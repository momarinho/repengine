#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_DIR="${ROOT_DIR}/api"
LOG_FILE="${RUNNER_TEMP:-/tmp}/repengine-api.log"
HEALTH_FILE="${RUNNER_TEMP:-/tmp}/repengine-health.json"
PORT="${PORT:-8080}"
HEALTH_URL="http://127.0.0.1:${PORT}/health"
GO_CACHE_DIR="${RUNNER_TEMP:-/tmp}/go-build-cache"
GO_MOD_CACHE_DIR="${RUNNER_TEMP:-/tmp}/go-mod-cache"

: "${DATABASE_URL:?DATABASE_URL is required}"
: "${JWT_SECRET:?JWT_SECRET is required}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

cd "${API_DIR}"

mkdir -p "${GO_CACHE_DIR}" "${GO_MOD_CACHE_DIR}"

env \
  GOCACHE="${GOCACHE:-${GO_CACHE_DIR}}" \
  GOMODCACHE="${GOMODCACHE:-${GO_MOD_CACHE_DIR}}" \
  go run ./cmd/server >"${LOG_FILE}" 2>&1 &
SERVER_PID=$!

for _ in {1..30}; do
  if curl -fsS "${HEALTH_URL}" >"${HEALTH_FILE}"; then
    if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
      echo "server exited after health probe"
      cat "${LOG_FILE}"
      exit 1
    fi
    break
  fi

  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    echo "server exited early"
    cat "${LOG_FILE}"
    exit 1
  fi

  sleep 1
done

if ! curl -fsS "${HEALTH_URL}" >"${HEALTH_FILE}"; then
  echo "server failed to become healthy within timeout"
  cat "${LOG_FILE}"
  exit 1
fi

cat "${HEALTH_FILE}"

if ! grep -q '"db":"ok"' "${HEALTH_FILE}"; then
  echo "health check did not report db ok"
  cat "${HEALTH_FILE}"
  exit 1
fi
