#!/usr/bin/env bash
# =============================================================================
# RepEngine — Production Deploy Script
#
# Usage:
#   ./deploy.sh            # Rebuilds and deploys api and web (default)
#   ./deploy.sh all        # Rebuilds all services in docker-compose.prod.yml
#   ./deploy.sh <services> # Deploys specific services (e.g. ./deploy.sh web)
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

# 2. Build and restart containers
TARGET_SERVICES="${*:-api web}"
if [[ "$TARGET_SERVICES" == "all" ]]; then
    TARGET_SERVICES=""
fi

echo ""
if [[ -n "$TARGET_SERVICES" ]]; then
    echo "🔨 [2/4] Building and updating services: $TARGET_SERVICES..."
    docker compose -f docker-compose.prod.yml up -d --build $TARGET_SERVICES
else
    echo "🔨 [2/4] Building and updating all services..."
    docker compose -f docker-compose.prod.yml up -d --build
fi

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

# Check health inside container or via curl
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
