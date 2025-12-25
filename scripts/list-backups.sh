#!/bin/bash
# =============================================================================
# List Available Backups
# Dùng: ./scripts/list-backups.sh
# =============================================================================

BACKUP_DIR="$HOME/backups/aw-visitor"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=============================================="
echo "  AVAILABLE BACKUPS"
echo "=============================================="
echo ""

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup directory found at: $BACKUP_DIR"
    exit 0
fi

# Full backups
echo -e "${BLUE}📦 Full Backups:${NC}"
echo "----------------------------------------"
for dir in $(ls -dt "$BACKUP_DIR"/full_* 2>/dev/null | head -10); do
    SIZE=$(du -sh "$dir" | cut -f1)
    DATE=$(basename "$dir" | sed 's/full_\([0-9]*_[0-9]*\).*/\1/')
    REASON=$(basename "$dir" | sed 's/full_[0-9]*_[0-9]*_//')
    echo -e "  ${GREEN}$dir${NC}"
    echo "    Size: $SIZE | Reason: $REASON"
    
    # Show contents
    if [ -f "$dir/db.sql.gz" ]; then
        DB_SIZE=$(ls -lh "$dir/db.sql.gz" | awk '{print $5}')
        echo "    └─ Database: $DB_SIZE"
    fi
    if [ -f "$dir/storage.tar.gz" ]; then
        ST_SIZE=$(ls -lh "$dir/storage.tar.gz" | awk '{print $5}')
        echo "    └─ Storage: $ST_SIZE"
    fi
    echo ""
done

# Database backups
echo -e "${BLUE}🗄️  Database Backups:${NC}"
echo "----------------------------------------"
ls -lht "$BACKUP_DIR"/db_*.sql.gz 2>/dev/null | head -10 | while read line; do
    echo "  $line"
done
echo ""

# Storage backups
echo -e "${BLUE}📁 Storage Backups:${NC}"
echo "----------------------------------------"
ls -lht "$BACKUP_DIR"/storage_*.tar.gz 2>/dev/null | head -10 | while read line; do
    echo "  $line"
done
echo ""

# Disk usage
echo -e "${YELLOW}💾 Total backup size:${NC}"
du -sh "$BACKUP_DIR" 2>/dev/null || echo "N/A"
echo ""

# Disk space available
echo -e "${YELLOW}💿 Disk space available:${NC}"
df -h "$BACKUP_DIR" | tail -1
echo ""

