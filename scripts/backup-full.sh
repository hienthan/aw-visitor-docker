#!/bin/bash
# =============================================================================
# Full Backup Script (Database + Storage + Config)
# Dùng: ./scripts/backup-full.sh [reason]
# Ví dụ: ./scripts/backup-full.sh "before-deploy-v2.0"
# =============================================================================

set -e

# Config
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REASON="${1:-manual}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/backups/aw-visitor/full_${TIMESTAMP}_${REASON}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  FULL BACKUP - AW-VISITOR"
echo "  Time: $(date)"
echo "  Reason: $REASON"
echo "=============================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
cd "$PROJECT_DIR"

# Step 1: Backup Database
log_step "1/5 Backing up database..."
if docker ps --format '{{.Names}}' | grep -q "aw-visitor-postgres"; then
    docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db | gzip > "$BACKUP_DIR/db.sql.gz"
    SIZE=$(ls -lh "$BACKUP_DIR/db.sql.gz" | awk '{print $5}')
    log_info "Database backup: $SIZE"
else
    log_warn "PostgreSQL container not running, skipping database backup"
fi

# Step 2: Backup Storage
log_step "2/5 Backing up storage files..."
if [ -d "aw-visitor-backend-adonisjs/storage" ]; then
    tar -czf "$BACKUP_DIR/storage.tar.gz" aw-visitor-backend-adonisjs/storage/
    SIZE=$(ls -lh "$BACKUP_DIR/storage.tar.gz" | awk '{print $5}')
    log_info "Storage backup: $SIZE"
else
    log_warn "No storage directory found"
fi

# Step 3: Backup .env
log_step "3/5 Backing up environment files..."
if [ -f ".env" ]; then
    cp .env "$BACKUP_DIR/.env.backup"
    log_info ".env backed up"
else
    log_warn "No .env file found"
fi

# Step 4: Record versions
log_step "4/5 Recording current versions..."

# Git commit
if [ -d ".git" ]; then
    git log -1 --format="%H|%s|%ai" > "$BACKUP_DIR/git_info.txt"
    git diff --stat > "$BACKUP_DIR/git_diff.txt" 2>/dev/null || true
    log_info "Git info recorded"
fi

# Docker images
docker compose images > "$BACKUP_DIR/docker_images.txt" 2>/dev/null || true
docker compose ps > "$BACKUP_DIR/docker_status.txt" 2>/dev/null || true
log_info "Docker info recorded"

# Step 5: Create manifest
log_step "5/5 Creating manifest..."
cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
===========================================
BACKUP MANIFEST
===========================================
Created: $(date -Iseconds)
Reason: $REASON
Host: $(hostname)
User: $(whoami)

FILES IN THIS BACKUP:
$(ls -lh "$BACKUP_DIR")

GIT COMMIT:
$(cat "$BACKUP_DIR/git_info.txt" 2>/dev/null || echo "N/A")

DOCKER STATUS:
$(cat "$BACKUP_DIR/docker_status.txt" 2>/dev/null || echo "N/A")

TO RESTORE:
./scripts/restore.sh $BACKUP_DIR
===========================================
EOF

# Summary
echo ""
echo "=============================================="
echo "  BACKUP COMPLETED ✅"
echo "=============================================="
echo ""
log_info "Backup location: $BACKUP_DIR"
echo ""
ls -lh "$BACKUP_DIR"
echo ""
log_info "Total size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "To restore this backup, run:"
echo -e "${YELLOW}  ./scripts/restore.sh $BACKUP_DIR${NC}"
echo ""

