#!/bin/bash
# =============================================================================
# Save Docker Image Script
# =============================================================================
# Mục đích: Save Docker image để copy lên server
# Usage: ./scripts/save-image.sh [IMAGE_NAME] [OUTPUT_DIR]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="${1:-aw-visitor-backend:latest}"
OUTPUT_DIR="${2:-$PROJECT_ROOT/docker-images}"

# Parse image name and tag
IMAGE_BASE=$(echo $IMAGE_NAME | cut -d: -f1)
IMAGE_TAG=$(echo $IMAGE_NAME | cut -d: -f2)
IMAGE_FILE="$OUTPUT_DIR/${IMAGE_BASE}_${IMAGE_TAG}.tar.gz"

echo "=========================================="
echo "Saving Docker Image..."
echo "=========================================="
echo "Image: $IMAGE_NAME"
echo "Output: $IMAGE_FILE"
echo ""

# Check if image exists
if ! docker images | grep -q "$(echo $IMAGE_NAME | cut -d: -f1)"; then
    echo "❌ Error: Image not found: $IMAGE_NAME"
    echo ""
    echo "Available images:"
    docker images | grep -E "REPOSITORY|aw-visitor" || echo "No aw-visitor images found"
    echo ""
    echo "Build image first:"
    echo "  docker compose build backend"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Save image
echo "💾 Saving image..."
docker save "$IMAGE_NAME" | gzip > "$IMAGE_FILE"

# Get file size
FILE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)

echo ""
echo "✅ Image saved successfully!"
echo "   File: $IMAGE_FILE"
echo "   Size: $FILE_SIZE"
echo ""
echo "Next steps:"
echo "  1. Copy to server: scp $IMAGE_FILE ps@10.1.16.50:/home/ps/docker-images/"
echo "  2. Load on server: docker load < /home/ps/docker-images/$(basename $IMAGE_FILE)"

