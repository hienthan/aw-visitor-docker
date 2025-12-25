#!/bin/bash
# =============================================================================
# Restore Script
# Dùng: ./scripts/restore.sh <backup_dir> [--skip-db] [--skip-storage] [--yes]
# =============================================================================

set -e

# Parse arguments
BACKUP_DIR=""
SKIP_DB=false
SKIP_STORAGE=false
AUTO_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-db) SKIP_DB=true; shift ;;
        --skip-storage) SKIP_STORAGE=true; shift ;;
        --yes|-y) AUTO_CONFIRM=true; shift ;;
        *) BACKUP_DIR="$1"; shift ;;
    esac
done

# Config
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

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

# Validate
if [ -z "$BACKUP_DIR" ]; then
    log_error "Usage: $0 <backup_dir> [--skip-db] [--skip-storage] [--yes]"
    echo ""
    echo "Available backups:"
    ls -dt ~/backups/aw-visitor/*/ 2>/dev/null | head -10 || echo "No backups found"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

echo ""
echo "=============================================="
echo "  RESTORE FROM BACKUP"
echo "=============================================="
echo ""
log_info "Backup source: $BACKUP_DIR"
echo ""

# Show manifest if exists
if [ -f "$BACKUP_DIR/MANIFEST.txt" ]; then
    echo "Backup manifest:"
    cat "$BACKUP_DIR/MANIFEST.txt"
    echo ""
fi

# Show what will be restored
echo "Will restore:"
[ -f "$BACKUP_DIR/db.sql.gz" ] && [ "$SKIP_DB" = false ] && echo "  ✓ Database"
[ -f "$BACKUP_DIR/storage.tar.gz" ] && [ "$SKIP_STORAGE" = false ] && echo "  ✓ Storage files"
[ -f "$BACKUP_DIR/.env.backup" ] && echo "  ✓ Environment file (.env)"
echo ""

# Confirmation
if [ "$AUTO_CONFIRM" = false ]; then
    echo -e "${YELLOW}⚠️  WARNING: This will OVERWRITE current data!${NC}"
    read -p "Continue? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Restore cancelled."
        exit 0
    fi
fi

cd "$PROJECT_DIR"

# Step 1: Stop services
log_step "1/5 Stopping services..."
docker compose stop backend frontend 2>/dev/null || true
log_info "Services stopped"

# Step 2: Restore Database
if [ -f "$BACKUP_DIR/db.sql.gz" ] && [ "$SKIP_DB" = false ]; then
    log_step "2/5 Restoring database..."
    
    # Check if postgres is running
    if ! docker ps --format '{{.Names}}' | grep -q "aw-visitor-postgres"; then
        log_info "Starting PostgreSQL..."
        docker compose up -d postgres
        sleep 10
    fi
    
    # Terminate connections
    docker exec -t aw-visitor-postgres psql -U postgres -c "
    SELECT pg_terminate_backend(pg_stat_activity.pid)
    FROM pg_stat_activity
    WHERE pg_stat_activity.datname = 'visitor_db'
    AND pid <> pg_backend_pid();
    " 2>/dev/null || true
    
    # Drop and recreate
    docker exec -t aw-visitor-postgres psql -U postgres -c "DROP DATABASE IF EXISTS visitor_db;" 2>/dev/null || true
    docker exec -t aw-visitor-postgres psql -U postgres -c "CREATE DATABASE visitor_db;"
    
    # Restore
    zcat "$BACKUP_DIR/db.sql.gz" | docker exec -i aw-visitor-postgres psql -U postgres -d visitor_db
    
    log_info "Database restored ✓"
else
    log_step "2/5 Skipping database restore"
fi

# Step 3: Restore Storage
if [ -f "$BACKUP_DIR/storage.tar.gz" ] && [ "$SKIP_STORAGE" = false ]; then
    log_step "3/5 Restoring storage files..."
    
    # Backup current storage
    if [ -d "aw-visitor-backend-adonisjs/storage" ]; then
        mv aw-visitor-backend-adonisjs/storage "aw-visitor-backend-adonisjs/storage.old.$(date +%s)"
    fi
    
    # Extract
    tar -xzf "$BACKUP_DIR/storage.tar.gz"
    
    log_info "Storage restored ✓"
else
    log_step "3/5 Skipping storage restore"
fi

# Step 4: Restore .env
if [ -f "$BACKUP_DIR/.env.backup" ]; then
    log_step "4/5 Restoring environment file..."
    
    # Backup current .env
    if [ -f ".env" ]; then
        cp .env ".env.old.$(date +%s)"
    fi
    
    cp "$BACKUP_DIR/.env.backup" .env
    log_info ".env restored ✓"
else
    log_step "4/5 No .env file in backup"
fi

# Step 5: Restart services
log_step "5/5 Starting services..."
docker compose up -d
sleep 5

# Verify
echo ""
log_info "Checking service status..."
docker compose ps

# Health check
echo ""
log_info "Waiting for health checks..."
sleep 10
docker compose ps

echo ""
echo "=============================================="
echo "  RESTORE COMPLETED ✅"
echo "=============================================="
echo ""
log_info "Services are starting. Check logs with:"
echo "  docker compose logs -f"
echo ""

