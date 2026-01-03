#!/bin/bash
# =============================================================================
# Production Deploy Script
# =============================================================================
# Mục đích: Deploy build folder lên production server
# Usage: ./scripts/deploy-production.sh [BUILD_FOLDER_PATH]
# 
# Environment variables:
#   DOCKER_IMAGE_NAME - Image name (default: aw-visitor-backend)
#   DOCKER_IMAGE_VERSION - Image version (default: latest)
# 
# Examples:
#   ./scripts/deploy-production.sh
#   DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh
#   DOCKER_IMAGE_NAME=aw-visitor-backend DOCKER_IMAGE_VERSION=v1.2.3 ./scripts/deploy-production.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/aw-visitor-backend-adonisjs"
BUILD_TARGET="$BACKEND_DIR/build"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKEND_DIR/build.backup.$TIMESTAMP"

echo "=========================================="
echo "Production Deploy..."
echo "=========================================="
echo ""
echo "ℹ️  Note: node_modules is in Docker image, not in build folder"
echo "   - Build folder only contains compiled code"
echo "   - Docker will merge: /app/node_modules (image) + /app/build (host)"
echo ""

# Function: Validate build folder
validate_build() {
    local build_path="$1"
    
    if [ ! -d "$build_path" ]; then
        echo "❌ Error: Build folder not found: $build_path"
        return 1
    fi
    
    # Check for server.js in multiple possible locations
    local server_file=""
    local found_files=()
    
    # Try different paths (check common structures)
    for path in "$build_path/bin/server.js" "$build_path/app/bin/server.js" "$build_path/server.js" "$build_path/../bin/server.js"; do
        if [ -f "$path" ]; then
            server_file="$path"
            break
        fi
    done
    
    # If not found, search for any server.js
    if [ -z "$server_file" ]; then
        found_files=($(find "$build_path" -name "server.js" -type f 2>/dev/null))
        if [ ${#found_files[@]} -gt 0 ]; then
            server_file="${found_files[0]}"
        fi
    fi
    
    if [ -z "$server_file" ]; then
        echo "❌ Error: server.js not found in build folder"
        echo "   Expected locations:"
        echo "     - $build_path/bin/server.js"
        echo "     - $build_path/app/bin/server.js"
        echo "     - $build_path/server.js"
        echo ""
        echo "   Build folder structure:"
        ls -la "$build_path" 2>/dev/null | head -10 | sed 's/^/     /'
        echo ""
        echo "   All .js files found:"
        find "$build_path" -name "*.js" -type f 2>/dev/null | head -10 | sed 's/^/     /'
        return 1
    fi
    
    # Check for essential directories
    local missing_dirs=()
    [ ! -d "$build_path/app" ] && missing_dirs+=("app")
    [ ! -d "$build_path/config" ] && missing_dirs+=("config")
    
    if [ ${#missing_dirs[@]} -gt 0 ]; then
        echo "⚠️  Warning: Missing directories: ${missing_dirs[*]}"
        echo "   Build may be incomplete, but continuing..."
    fi
    
    echo "✅ Build folder validated: $server_file found"
    return 0
}

# Function: Backup current build
backup_current() {
    if [ -d "$BUILD_TARGET" ]; then
        echo "💾 Backing up current build..."
        mv "$BUILD_TARGET" "$BACKUP_DIR"
        echo "   Backup saved: $BACKUP_DIR"
    fi
}

# Function: Rollback on error
rollback() {
    if [ -d "$BACKUP_DIR" ]; then
        echo ""
        echo "⚠️  Rolling back to previous build..."
        rm -rf "$BUILD_TARGET"
        mv "$BACKUP_DIR" "$BUILD_TARGET"
        echo "✅ Rollback completed"
    fi
}

# Handle build folder source
if [ -n "$1" ]; then
    BUILD_SOURCE="$1"
    
    # Resolve absolute path
    if [ ! -d "$BUILD_SOURCE" ]; then
        echo "❌ Error: Build folder not found: $BUILD_SOURCE"
        exit 1
    fi
    
    BUILD_SOURCE=$(cd "$BUILD_SOURCE" && pwd)
    
    # Validate source build folder
    if ! validate_build "$BUILD_SOURCE"; then
        exit 1
    fi
    
    # Backup current
    backup_current
    
    # Copy new build
    echo "📋 Copying build folder..."
    mkdir -p "$BACKEND_DIR"
    cp -r "$BUILD_SOURCE" "$BUILD_TARGET"
    
    # Ensure storage folder exists
    mkdir -p "$BUILD_TARGET/storage/app"
    
    echo "✅ Build folder copied"
fi

# Validate target build folder
if [ ! -d "$BUILD_TARGET" ]; then
    echo "❌ Error: Build folder not found at $BUILD_TARGET"
    echo ""
    echo "Usage:"
    echo "  ./scripts/deploy-production.sh /path/to/build"
    exit 1
fi

if ! validate_build "$BUILD_TARGET"; then
    rollback
    exit 1
fi

# Check if Docker image exists
echo ""
echo "🔍 Checking Docker image..."
cd "$PROJECT_ROOT"

# Parse image name and version from environment or use defaults
IMAGE_NAME="${DOCKER_IMAGE_NAME:-aw-visitor-backend}"
IMAGE_VERSION="${DOCKER_IMAGE_VERSION:-latest}"
FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_VERSION"

if ! docker images | grep -q "$IMAGE_NAME"; then
    echo "⚠️  Docker image not found!"
    echo ""
    echo "   Image '$FULL_IMAGE_NAME' is required."
    echo "   It contains node_modules and is built from Dockerfile."
    echo ""
    echo "   Available options:"
    echo "     1. Load from file:"
    echo "        export DOCKER_IMAGE_VERSION=v1.0.0"
    echo "        ./scripts/load-image.sh /home/ps/docker-images/${IMAGE_NAME}_${IMAGE_VERSION}.tar.gz"
    echo ""
    echo "     2. Build on server (not recommended):"
    echo "        docker compose build backend"
    echo ""
    echo "   Current image name: $IMAGE_NAME"
    echo "   Current version: $IMAGE_VERSION"
    echo "   Set environment variables to use different version:"
    echo "     export DOCKER_IMAGE_NAME=aw-visitor-backend"
    echo "     export DOCKER_IMAGE_VERSION=v1.0.0"
    echo ""
    rollback
    exit 1
fi

# Check if specific version exists, fallback to latest
if ! docker images | grep -q "$FULL_IMAGE_NAME"; then
    echo "⚠️  Image version '$IMAGE_VERSION' not found, checking for 'latest'..."
    if docker images | grep -q "$IMAGE_NAME.*latest"; then
        echo "✅ Found 'latest' version, will use that"
        FULL_IMAGE_NAME="$IMAGE_NAME:latest"
    else
        echo "❌ No image found for $IMAGE_NAME"
        echo ""
        echo "   Available images:"
        docker images | grep -E "REPOSITORY|$IMAGE_NAME" || echo "   None found"
        echo ""
        rollback
        exit 1
    fi
else
    echo "✅ Docker image found: $FULL_IMAGE_NAME"
fi

# Tag image as latest if using specific version (for docker-compose compatibility)
if [ "$IMAGE_VERSION" != "latest" ]; then
    echo "📌 Tagging $FULL_IMAGE_NAME as latest (for docker-compose)..."
    docker tag "$FULL_IMAGE_NAME" "$IMAGE_NAME:latest" || true
fi

# Restart container with error handling
echo ""
echo "🔄 Restarting backend container..."

# Check if container exists
if ! docker compose ps backend >/dev/null 2>&1; then
    echo "⚠️  Container not running, starting..."
    docker compose up -d backend
else
    docker compose restart backend
fi

# Wait a moment for container to start
sleep 2

# Verify container is running
if ! docker compose ps backend 2>/dev/null | grep -q "Up"; then
    echo "❌ Error: Container failed to start"
    echo ""
    echo "📋 Checking logs (last 50 lines)..."
    echo "=========================================="
    docker compose logs --tail 50 backend 2>/dev/null || docker logs aw-visitor-backend --tail 50 2>/dev/null || echo "Cannot access logs"
    echo "=========================================="
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check if Docker image exists: docker images | grep aw-visitor-backend"
    echo "   2. If image missing, build it: docker compose build backend"
    echo "   3. View full logs: docker compose logs -f backend"
    echo "   4. Check container: docker compose ps backend"
    rollback
    exit 1
fi

# Success
echo ""
echo "=========================================="
echo "✅ Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Container status:"
docker compose ps backend
echo ""
echo "View logs:"
echo "  docker compose logs -f backend"
echo ""
if [ -d "$BACKUP_DIR" ]; then
    echo "Previous build backup: $BACKUP_DIR"
    echo "  (Remove after verifying new build works)"
fi

