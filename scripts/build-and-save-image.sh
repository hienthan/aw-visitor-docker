#!/bin/bash
# =============================================================================
# Build and Save Image Script
# =============================================================================
# Mục đích: Build image và save với version để deploy lên server
# Usage: ./scripts/build-and-save-image.sh [VERSION]
# 
# Examples:
#   ./scripts/build-and-save-image.sh              # Build và save với :latest
#   ./scripts/build-and-save-image.sh v1.0.0       # Build và save với :v1.0.0
#   ./scripts/build-and-save-image.sh 1.2.3        # Build và save với :1.2.3
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-latest}"
IMAGE_NAME="aw-visitor-backend:$VERSION"
SERVER_IMAGES_DIR="/home/ps/docker-images"

echo "=========================================="
echo "Build and Save Docker Image..."
echo "=========================================="
echo "Version: $VERSION"
echo "Image: $IMAGE_NAME"
echo ""

# Step 1: Build image với tag
echo "Step 1: Building Docker image..."
cd "$PROJECT_ROOT"

# Build với tag cụ thể
docker compose build backend
docker tag aw-visitor-backend:latest "$IMAGE_NAME"

# Step 2: Save image với version
echo ""
echo "Step 2: Saving Docker image..."
"$SCRIPT_DIR/save-image.sh" "$IMAGE_NAME"

# Step 3: Also save as latest (for convenience)
if [ "$VERSION" != "latest" ]; then
    echo ""
    echo "Step 3: Also tagging as latest..."
    docker tag "$IMAGE_NAME" aw-visitor-backend:latest
    "$SCRIPT_DIR/save-image.sh" aw-visitor-backend:latest
fi

echo ""
echo "=========================================="
echo "✅ Done!"
echo "=========================================="
echo ""
echo "📦 Images saved:"
ls -lh docker-images/aw-visitor-backend_*.tar.gz 2>/dev/null | tail -2 | awk '{print "   " $9 " (" $5 ")"}'
echo ""
echo "🚀 Next steps to deploy to server:"
echo "   1. Copy image to server:"
echo "      scp docker-images/aw-visitor-backend_${VERSION}.tar.gz ps@10.1.16.50:$SERVER_IMAGES_DIR/"
echo ""
echo "   2. On server, load image:"
echo "      ./scripts/load-image.sh $SERVER_IMAGES_DIR/aw-visitor-backend_${VERSION}.tar.gz"
echo ""
echo "   3. Deploy code:"
echo "      ./scripts/deploy-production.sh"

