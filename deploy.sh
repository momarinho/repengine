#!/usr/bin/env bash
# =============================================================================
# RepEngine — Fast Production Deploy Script
#
# Usage:
#   ./deploy.sh            # Pulls pre-built images from GitHub (fast, ~15s)
#   ./deploy.sh --build    # Forces local compilation on the VPS (slower)
#   ./deploy.sh <services> # Deploys specific services (e.g. ./deploy.sh web)
#   ./deploy.sh all        # Deploys all services in docker-compose.prod.yml
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "🚀 Starting RepEngine Production Deploy"
echo "========================================"

# 1. Update source code from Git
echo ""
echo "📥 [1/4] Pulling latest changes from Git..."
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
git pull origin "$CURRENT_BRANCH"

# 2. Update containers
# By default, we pull pre-built images from GitHub Actions (takes ~15s instead of 13 minutes!).
# If --build is explicitly passed or pull fails, it falls back to local build.
FORCE_BUILD=false
ARGS=()
for arg in "$@"; do
    if [[ "$arg" == "--build" ]]; then
        FORCE_BUILD=true
    else
        ARGS+=("$arg")
    fi
done

TARGET_SERVICES="${ARGS[*]:-api web}"
if [[ "$TARGET_SERVICES" == "all" ]]; then
    TARGET_SERVICES=""
fi

echo ""
if [[ "$FORCE_BUILD" == true ]]; then
    echo "🔨 [2/4] Compiling locally on VPS (--build specified)..."
    docker compose -f docker-compose.prod.yml up -d --build $TARGET_SERVICES
else
    echo "⚡ [2/4] Pulling pre-built images from GitHub Container Registry..."
    if docker compose -f docker-compose.prod.yml pull $TARGET_SERVICES 2>/dev/null; then
        echo "🚀 Deploying updated containers..."
        docker compose -f docker-compose.prod.yml up -d $TARGET_SERVICES
    else
        echo "⚠️ Pre-built images not available. Falling back to local build..."
        docker compose -f docker-compose.prod.yml up -d --build $TARGET_SERVICES
    fi
fi

# Reload Nginx configuration to apply proxy/rate-limiting updates
docker compose -f docker-compose.prod.yml exec -T nginx nginx -s reload >/dev/null 2>&1 || true

# 3. Clean up dangling images to preserve VPS disk space
echo ""
echo "🧹 [3/4] Cleaning up dangling docker images..."
docker image prune -f >/dev/null 2>&1 || true

# 4. Status and Health Check
echo ""
echo "📊 [4/4] Verifying deployment..."
docker compose -f docker-compose.prod.yml ps

echo ""
echo "🩺 Testing API health..."
sleep 2

HEALTHY=false
for i in {1..6}; do
    if docker compose -f docker-compose.prod.yml exec -T api wget -qO- http://localhost:8080/health >/dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    echo "   Waiting for API to be ready ($i/6)..."
    sleep 2
done

if [[ "$HEALTHY" == true ]]; then
    echo "✅ API is healthy and operational!"
else
    echo "⚠️ Warning: API health check timed out. Inspect logs with:"
    echo "   docker compose -f docker-compose.prod.yml logs --tail=30 api"
fi

echo ""
echo "========================================"
echo "🎉 Deploy finished successfully!"
echo "📌 Commit: $(git log -1 --pretty=format:'%h - %s (%cr)')"
echo "========================================"
