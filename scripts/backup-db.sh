#!/bin/bash
# =============================================================================
# Database Backup Script
# Dùng: ./scripts/backup-db.sh [backup_dir]
# =============================================================================

set -e  # Exit on error

# Config
CONTAINER_NAME="aw-visitor-postgres"
DB_USER="postgres"
DB_NAME="visitor_db"
BACKUP_DIR="${1:-$HOME/backups/aw-visitor}"
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/db_${TIMESTAMP}.sql.gz"

log_info "Starting database backup..."
log_info "Container: $CONTAINER_NAME"
log_info "Database: $DB_NAME"
log_info "Output: $BACKUP_FILE"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Container $CONTAINER_NAME is not running!"
    exit 1
fi

# Perform backup
log_info "Dumping database..."
docker exec -t "$CONTAINER_NAME" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Verify backup
if [ ! -s "$BACKUP_FILE" ]; then
    log_error "Backup file is empty!"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Get file size
SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
log_info "Backup completed: $SIZE"

# Cleanup old backups
log_info "Cleaning up backups older than $RETENTION_DAYS days..."
DELETED=$(find "$BACKUP_DIR" -name "db_*.sql.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
log_info "Deleted $DELETED old backup(s)"

# Summary
echo ""
log_info "=== Backup Summary ==="
log_info "File: $BACKUP_FILE"
log_info "Size: $SIZE"
log_info "Remaining backups:"
ls -lt "$BACKUP_DIR"/db_*.sql.gz 2>/dev/null | head -5

echo ""
log_info "Done! ✅"

