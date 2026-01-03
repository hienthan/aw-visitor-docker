#!/bin/bash
# =============================================================================
# Copy Build to Server Script
# =============================================================================
# Mục đích: Copy build folder từ máy dev lên server
# Usage: ./scripts/copy-build-to-server.sh [SERVER_USER] [SERVER_HOST] [SERVER_PATH]
# 
# Defaults:
#   SERVER_USER=ps
#   SERVER_HOST=10.1.16.50
#   SERVER_PATH=/home/ps/main-apps/aw-visitor-docker/aw-visitor-backend-adonisjs
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/aw-visitor-backend-adonisjs"
BUILD_SOURCE="$BACKEND_DIR/build"

# Server config (có thể override bằng arguments hoặc env vars)
SERVER_USER="${1:-${SERVER_USER:-ps}}"
SERVER_HOST="${2:-${SERVER_HOST:-10.1.16.50}}"
SERVER_PATH="${3:-${SERVER_PATH:-/home/ps/main-apps/aw-visitor-docker/aw-visitor-backend-adonisjs}}"

echo "=========================================="
echo "Copy Build Folder to Server..."
echo "=========================================="
echo "Source: $BUILD_SOURCE"
echo "Destination: $SERVER_USER@$SERVER_HOST:$SERVER_PATH/build"
echo ""

# Check if build folder exists
if [ ! -d "$BUILD_SOURCE" ]; then
    echo "❌ Error: Build folder not found: $BUILD_SOURCE"
    echo ""
    echo "Build first:"
    echo "  ./scripts/build-backend.sh"
    exit 1
fi

# Check if server.js exists
if [ ! -f "$BUILD_SOURCE/bin/server.js" ]; then
    echo "⚠️  Warning: build/bin/server.js not found"
    echo "   Build may be incomplete"
    echo ""
    echo "   Found structure:"
    ls -la "$BUILD_SOURCE" | head -10 | sed 's/^/     /'
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Copy using rsync (better than scp - preserves permissions, can resume)
echo "📦 Copying build folder..."
echo ""

if command -v rsync &> /dev/null; then
    echo "Using rsync (recommended)..."
    rsync -avz --delete \
        --exclude 'storage/app' \
        "$BUILD_SOURCE/" \
        "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/build/"
else
    echo "Using scp..."
    # Remove old build on server first
    ssh "$SERVER_USER@$SERVER_HOST" "rm -rf $SERVER_PATH/build" || true
    
    # Copy build folder
    scp -r "$BUILD_SOURCE" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/"
fi

echo ""
echo "✅ Build folder copied successfully!"
echo ""
echo "Next steps on server:"
echo "  1. Deploy: ./scripts/deploy-production.sh"
echo "  2. Or with version: DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh"

