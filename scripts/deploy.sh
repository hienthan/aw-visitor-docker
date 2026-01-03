#!/bin/bash
# =============================================================================
# Deploy Script
# =============================================================================
# Mục đích: Build code + rebuild image + restart containers
# Usage: ./scripts/deploy.sh [--skip-build] [--skip-image]
# =============================================================================

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKIP_BUILD=false
SKIP_IMAGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-image)
            SKIP_IMAGE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-build] [--skip-image]"
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT"

echo "=========================================="
echo "Deploying AW-Visitor..."
echo "=========================================="

# 1. Build backend code (nếu không skip)
if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo "Step 1: Building backend code..."
    "$SCRIPT_DIR/build-backend.sh"
else
    echo "⏭️  Skipping code build (--skip-build)"
fi

# 2. Build Docker image (nếu không skip)
if [ "$SKIP_IMAGE" = false ]; then
    echo ""
    echo "Step 2: Building Docker image..."
    docker compose build backend
else
    echo "⏭️  Skipping image build (--skip-image)"
fi

# 3. Restart containers với image mới
echo ""
echo "Step 3: Restarting containers..."
docker compose up -d --no-deps backend

# 4. Show status
echo ""
echo "=========================================="
echo "Deployment completed!"
echo "=========================================="
echo ""
echo "Container status:"
docker compose ps

echo ""
echo "View logs:"
echo "  docker compose logs -f backend"

