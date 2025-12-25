#!/bin/bash
# =============================================================================
# Storage Backup Script
# Dùng: ./scripts/backup-storage.sh [backup_dir]
# =============================================================================

set -e

# Config
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STORAGE_PATH="$PROJECT_DIR/aw-visitor-backend-adonisjs/storage"
BACKUP_DIR="${1:-$HOME/backups/aw-visitor}"
RETENTION_DAYS=30

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/storage_${TIMESTAMP}.tar.gz"

log_info "Starting storage backup..."
log_info "Source: $STORAGE_PATH"
log_info "Output: $BACKUP_FILE"

# Check if storage exists
if [ ! -d "$STORAGE_PATH" ]; then
    log_warn "Storage directory does not exist. Creating empty backup marker."
    touch "$BACKUP_DIR/storage_${TIMESTAMP}_empty"
    exit 0
fi

# Count files
FILE_COUNT=$(find "$STORAGE_PATH" -type f | wc -l)
log_info "Files to backup: $FILE_COUNT"

# Perform backup
log_info "Creating archive..."
cd "$PROJECT_DIR"
tar -czf "$BACKUP_FILE" \
    --exclude='*.tmp' \
    --exclude='*.log' \
    --exclude='.gitkeep' \
    aw-visitor-backend-adonisjs/storage/

# Verify
SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
log_info "Backup completed: $SIZE"

# Cleanup old backups
log_info "Cleaning up backups older than $RETENTION_DAYS days..."
DELETED=$(find "$BACKUP_DIR" -name "storage_*.tar.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
log_info "Deleted $DELETED old backup(s)"

echo ""
log_info "=== Backup Summary ==="
log_info "File: $BACKUP_FILE"
log_info "Size: $SIZE"
log_info "Files backed up: $FILE_COUNT"

echo ""
log_info "Done! ✅"

