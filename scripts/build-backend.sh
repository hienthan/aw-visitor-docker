#!/bin/bash
# =============================================================================
# Build Backend Script
# =============================================================================
# Mục đích: Build backend code và tạo image Docker
# Usage: ./scripts/build-backend.sh
# =============================================================================

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/aw-visitor-backend-adonisjs"

echo "=========================================="
echo "Building Backend..."
echo "=========================================="

cd "$BACKEND_DIR"

# Clean build folder before building
if [ -d "build" ]; then
    ROOT_FILES=$(find build -user root 2>/dev/null | head -1)
    if [ -n "$ROOT_FILES" ]; then
        if ! rm -rf build 2>/dev/null; then
            echo "⚠️  Need sudo to remove build folder. Please run: sudo rm -rf $BACKEND_DIR/build"
            exit 1
        fi
    else
        rm -rf build
    fi
fi

# 1. Install dependencies (nếu chưa có node_modules)
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm ci
else
    echo "✅ node_modules already exists, skipping install"
fi

# 2. Build TypeScript code
echo "🔨 Building TypeScript code..."
npm run build

# Create storage folder
mkdir -p build/storage/app

# 3. Verify build output
if [ ! -d "build" ]; then
    echo "❌ Error: build folder not found after build"
    exit 1
fi

if [ ! -f "build/bin/server.js" ]; then
    echo "❌ Error: build/bin/server.js not found"
    exit 1
fi

echo "✅ Build completed successfully!"
echo ""
echo "📁 Build folder: $BACKEND_DIR/build"
echo ""
echo "Next steps:"
echo "  - Local: docker compose restart backend"
echo "  - Production: Copy build folder to server, then run ./scripts/deploy-production.sh"

