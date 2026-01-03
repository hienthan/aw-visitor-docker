#!/bin/bash
# =============================================================================
# Load Docker Image Script
# =============================================================================
# Mục đích: Load Docker image từ file
# Usage: ./scripts/load-image.sh [IMAGE_FILE]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default image directory
IMAGE_DIR="${DOCKER_IMAGES_DIR:-$PROJECT_ROOT/docker-images}"

if [ -n "$1" ]; then
    IMAGE_FILE="$1"
else
    # Find latest image file
    if [ -d "$IMAGE_DIR" ]; then
        IMAGE_FILE=$(ls -t "$IMAGE_DIR"/*.tar.gz 2>/dev/null | head -1)
    fi
fi

if [ -z "$IMAGE_FILE" ] || [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ Error: Image file not found"
    echo ""
    echo "Usage:"
    echo "  ./scripts/load-image.sh /path/to/image.tar.gz"
    echo ""
    echo "Or set DOCKER_IMAGES_DIR environment variable:"
    echo "  export DOCKER_IMAGES_DIR=/path/to/images"
    echo "  ./scripts/load-image.sh"
    exit 1
fi

echo "=========================================="
echo "Loading Docker Image..."
echo "=========================================="
echo "File: $IMAGE_FILE"
echo ""

# Get file size
FILE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)
echo "Size: $FILE_SIZE"
echo ""

# Load image
echo "📦 Loading image (this may take a while)..."
docker load < "$IMAGE_FILE"

echo ""
echo "✅ Image loaded successfully!"
echo ""
echo "Loaded images:"
docker images | grep -E "REPOSITORY|aw-visitor" || docker images | head -5

