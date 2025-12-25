# Docker Backup, Restore & Rollback - Hướng dẫn chi tiết

## Mục lục
1. [Tổng quan - Những gì cần backup](#1-tổng-quan---những-gì-cần-backup)
2. [Ngữ cảnh 1: Backup định kỳ (Daily/Weekly)](#2-ngữ-cảnh-1-backup-định-kỳ)
3. [Ngữ cảnh 2: Backup trước khi deploy/update](#3-ngữ-cảnh-2-backup-trước-deploy)
4. [Ngữ cảnh 3: Restore khi có sự cố](#4-ngữ-cảnh-3-restore-khi-có-sự-cố)
5. [Ngữ cảnh 4: Rollback về version cũ](#5-ngữ-cảnh-4-rollback-về-version-cũ)
6. [Ngữ cảnh 5: Migration sang server mới](#6-ngữ-cảnh-5-migration-sang-server-mới)
7. [Commands Reference](#7-commands-reference)

---

## 1. Tổng quan - Những gì cần backup

### Phân loại dữ liệu trong Docker project

```
aw-visitor-docker/
├── db/data/                    # 🔴 CRITICAL - Database data (PostgreSQL)
├── aw-visitor-backend-adonisjs/
│   └── storage/                # 🟠 IMPORTANT - Uploaded files (images, QR codes)
├── docker-compose.yml          # 🟢 RECOVERABLE - Config (có trong git)
├── .env                        # 🟠 IMPORTANT - Secrets (KHÔNG có trong git)
└── nginx/                      # 🟢 RECOVERABLE - Config (có trong git)
```

### Chiến lược backup theo loại dữ liệu

| Dữ liệu | Phương pháp | Tần suất | Retention |
|---------|-------------|----------|-----------|
| Database | `pg_dump` | Daily + Before deploy | 7 ngày + 1 tuần |
| Storage files | `tar` | Weekly | 4 tuần |
| .env secrets | Copy manual | Khi thay đổi | Vĩnh viễn |
| Docker images | Registry/local tag | Each deploy | 3 versions |

---

## 2. Ngữ cảnh 1: Backup định kỳ

### 2.1. Backup Database PostgreSQL

**Tình huống**: Bạn muốn backup database hàng ngày để phòng trường hợp data bị corrupt hoặc xóa nhầm.

```bash
# ============================================================
# BƯỚC 1: Xem database container đang chạy
# ============================================================
docker ps --filter "name=postgres"
# Output: aw-visitor-postgres (hoặc tên tương tự)

# ============================================================
# BƯỚC 2: Backup với pg_dump
# ============================================================
# Giải thích từng phần:
#   docker exec         : Chạy command trong container
#   -t                  : Allocate pseudo-TTY (cho output đẹp)
#   aw-visitor-postgres : Tên container
#   pg_dump             : PostgreSQL backup tool
#   -U postgres         : Username
#   visitor_db          : Tên database
#   > backup.sql        : Redirect output ra file

# Tạo folder backup nếu chưa có
mkdir -p ~/backups/aw-visitor

# Backup với timestamp
docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db > ~/backups/aw-visitor/db_$(date +%Y%m%d_%H%M%S).sql

# ============================================================
# BƯỚC 3: Nén file backup (tiết kiệm dung lượng)
# ============================================================
# Giải thích:
#   gzip -9  : Nén mức cao nhất
#   File .sql sẽ bị xóa, chỉ còn .sql.gz

gzip -9 ~/backups/aw-visitor/db_*.sql

# ============================================================
# BƯỚC 4: Verify backup
# ============================================================
# Xem size file
ls -lh ~/backups/aw-visitor/

# Kiểm tra file có đọc được không (giải nén và xem header)
zcat ~/backups/aw-visitor/db_20241224_*.sql.gz | head -50
```

### 2.2. Backup Storage Files (Uploaded images)

```bash
# ============================================================
# BƯỚC 1: Xác định đường dẫn storage
# ============================================================
ls -la aw-visitor-backend-adonisjs/storage/
# Thường chứa: qr codes, uploaded images, etc.

# ============================================================
# BƯỚC 2: Backup với tar
# ============================================================
# Giải thích:
#   tar     : Archive tool
#   -czvf   : Create, gZip, Verbose, File
#   --exclude : Bỏ qua các file tạm

cd /home/gmo021/hienthan/aw-visitor-docker

tar -czvf ~/backups/aw-visitor/storage_$(date +%Y%m%d).tar.gz \
    --exclude='*.tmp' \
    --exclude='*.log' \
    aw-visitor-backend-adonisjs/storage/

# ============================================================
# BƯỚC 3: Verify
# ============================================================
tar -tzvf ~/backups/aw-visitor/storage_$(date +%Y%m%d).tar.gz | head -20
```

### 2.3. Cleanup old backups (Retention policy)

```bash
# ============================================================
# Xóa database backups cũ hơn 7 ngày
# ============================================================
# Giải thích:
#   find          : Tìm files
#   -name "db_*"  : Pattern matching
#   -mtime +7     : Modified time > 7 ngày trước
#   -delete       : Xóa (cẩn thận!)

# Dry run trước (xem những gì sẽ bị xóa)
find ~/backups/aw-visitor -name "db_*.sql.gz" -mtime +7 -print

# Thực hiện xóa
find ~/backups/aw-visitor -name "db_*.sql.gz" -mtime +7 -delete

# Xóa storage backups cũ hơn 30 ngày
find ~/backups/aw-visitor -name "storage_*.tar.gz" -mtime +30 -delete
```

---

## 3. Ngữ cảnh 2: Backup trước deploy

### Tình huống: Bạn sắp deploy code mới, cần backup để có thể rollback nếu lỗi

```bash
# ============================================================
# FULL BACKUP BEFORE DEPLOY
# ============================================================

cd /home/gmo021/hienthan/aw-visitor-docker

# Tạo folder cho lần deploy này
DEPLOY_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/backups/aw-visitor/deploy_${DEPLOY_DATE}
mkdir -p $BACKUP_DIR

echo "📦 Creating pre-deploy backup at $BACKUP_DIR"

# 1. Backup database
echo "1/4 Backing up database..."
docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db | gzip > $BACKUP_DIR/db.sql.gz

# 2. Backup storage
echo "2/4 Backing up storage..."
tar -czf $BACKUP_DIR/storage.tar.gz aw-visitor-backend-adonisjs/storage/

# 3. Backup .env file
echo "3/4 Backing up .env..."
cp .env $BACKUP_DIR/.env.backup

# 4. Ghi lại Docker image versions hiện tại
echo "4/4 Recording current versions..."
docker compose images > $BACKUP_DIR/docker_images.txt
docker compose ps > $BACKUP_DIR/docker_status.txt
git log -1 --format="%H %s" > $BACKUP_DIR/git_commit.txt

# Summary
echo ""
echo "✅ Backup completed!"
ls -lh $BACKUP_DIR/
echo ""
echo "📝 To rollback, run:"
echo "   ./scripts/restore.sh $BACKUP_DIR"
```

### Lưu Docker Image trước khi update

```bash
# ============================================================
# TAG CURRENT IMAGE BEFORE PULLING NEW VERSION
# ============================================================

# Xem image hiện tại
docker images | grep -E "node|nginx"

# Tag image hiện tại với version/date để có thể rollback
# Syntax: docker tag <source> <target>
docker tag node:22-alpine node:22-alpine-backup-$(date +%Y%m%d)
docker tag nginx:alpine nginx:alpine-backup-$(date +%Y%m%d)

# Verify
docker images | grep backup
```

---

## 4. Ngữ cảnh 3: Restore khi có sự cố

### 4.1. Database bị corrupt / data sai

**Tình huống**: Deploy xong phát hiện data bị lỗi, cần restore về backup trước đó

```bash
# ============================================================
# BƯỚC 1: STOP APPLICATION (tránh ghi thêm data)
# ============================================================
cd /home/gmo021/hienthan/aw-visitor-docker
docker compose stop backend frontend
# Giải thích: Chỉ stop app, KHÔNG stop database

# ============================================================
# BƯỚC 2: Xem danh sách backups
# ============================================================
ls -lt ~/backups/aw-visitor/
# Chọn backup muốn restore (ví dụ: db_20241224_100000.sql.gz)

# ============================================================
# BƯỚC 3: RESTORE DATABASE
# ============================================================
# Cách 1: Drop và recreate database
BACKUP_FILE=~/backups/aw-visitor/db_20241224_100000.sql.gz

# Connect vào postgres và drop database
docker exec -it aw-visitor-postgres psql -U postgres -c "DROP DATABASE visitor_db;"

# Tạo lại database trống
docker exec -it aw-visitor-postgres psql -U postgres -c "CREATE DATABASE visitor_db;"

# Restore từ backup
# Giải thích:
#   zcat        : Giải nén và output ra stdout
#   | docker exec -i : Pipe vào container (chú ý -i không phải -t)
#   psql        : PostgreSQL CLI
zcat $BACKUP_FILE | docker exec -i aw-visitor-postgres psql -U postgres -d visitor_db

# ============================================================
# BƯỚC 4: Verify restore
# ============================================================
# Đếm số records trong các bảng chính
docker exec -t aw-visitor-postgres psql -U postgres -d visitor_db -c "
SELECT 
    schemaname,
    relname as table_name,
    n_live_tup as row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
"

# ============================================================
# BƯỚC 5: Restart application
# ============================================================
docker compose start backend frontend

# Xem logs để verify
docker compose logs -f --tail=50
```

### 4.2. Restore Storage Files

```bash
# ============================================================
# RESTORE UPLOADED FILES
# ============================================================
cd /home/gmo021/hienthan/aw-visitor-docker

# Stop backend để tránh conflict
docker compose stop backend

# Backup current storage (phòng trường hợp cần)
mv aw-visitor-backend-adonisjs/storage aw-visitor-backend-adonisjs/storage.broken

# Extract backup
tar -xzvf ~/backups/aw-visitor/storage_20241224.tar.gz

# Verify
ls -la aw-visitor-backend-adonisjs/storage/

# Restart
docker compose start backend
```

---

## 5. Ngữ cảnh 4: Rollback về version cũ

### 5.1. Rollback Code (Git)

```bash
# ============================================================
# BƯỚC 1: Xem commit history
# ============================================================
cd /home/gmo021/hienthan/aw-visitor-docker
git log --oneline -20

# ============================================================
# BƯỚC 2: Rollback về commit cụ thể
# ============================================================
# Cách 1: Soft reset (giữ changes, không commit)
git checkout <commit-hash> -- .

# Cách 2: Hard reset (mất hết changes sau commit đó)
# ⚠️ NGUY HIỂM - Chỉ dùng khi chắc chắn
git reset --hard <commit-hash>

# Cách 3: Revert (tạo commit mới để undo)
# ✅ RECOMMENDED - Không mất history
git revert <commit-hash>

# ============================================================
# BƯỚC 3: Rebuild nếu cần
# ============================================================
docker compose down
docker compose up -d --build
```

### 5.2. Rollback Docker Image

```bash
# ============================================================
# ROLLBACK TO PREVIOUS IMAGE VERSION
# ============================================================

# Xem các image backup đã tag
docker images | grep backup

# Sửa docker-compose.yml để dùng image cũ
# Hoặc chạy trực tiếp:
docker compose down
docker compose up -d --pull never  # Không pull image mới
```

### 5.3. Full Rollback (Code + Database + Files)

```bash
# ============================================================
# FULL ROLLBACK PROCEDURE
# ============================================================

BACKUP_DIR=~/backups/aw-visitor/deploy_20241224_100000

# 1. Stop everything
cd /home/gmo021/hienthan/aw-visitor-docker
docker compose down

# 2. Restore code từ git
git stash  # Lưu changes hiện tại
cat $BACKUP_DIR/git_commit.txt  # Xem commit cần rollback
git checkout <commit-hash>

# 3. Start database only
docker compose up -d postgres

# 4. Wait for postgres to be ready
sleep 10

# 5. Restore database
docker exec -it aw-visitor-postgres psql -U postgres -c "DROP DATABASE IF EXISTS visitor_db;"
docker exec -it aw-visitor-postgres psql -U postgres -c "CREATE DATABASE visitor_db;"
zcat $BACKUP_DIR/db.sql.gz | docker exec -i aw-visitor-postgres psql -U postgres -d visitor_db

# 6. Restore storage
rm -rf aw-visitor-backend-adonisjs/storage
tar -xzf $BACKUP_DIR/storage.tar.gz

# 7. Restore .env
cp $BACKUP_DIR/.env.backup .env

# 8. Start all services
docker compose up -d

# 9. Verify
docker compose ps
docker compose logs -f --tail=100
```

---

## 6. Ngữ cảnh 5: Migration sang server mới

### Tình huống: Di chuyển toàn bộ project sang server khác

```bash
# ============================================================
# TRÊN SERVER CŨ: Export everything
# ============================================================

cd /home/gmo021/hienthan/aw-visitor-docker

MIGRATION_DIR=~/migration_$(date +%Y%m%d)
mkdir -p $MIGRATION_DIR

# 1. Backup database
docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db | gzip > $MIGRATION_DIR/db.sql.gz

# 2. Backup storage
tar -czf $MIGRATION_DIR/storage.tar.gz aw-visitor-backend-adonisjs/storage/

# 3. Backup .env
cp .env $MIGRATION_DIR/

# 4. Export Docker images (nếu có custom image)
# docker save aw-visitor-backend:latest | gzip > $MIGRATION_DIR/backend-image.tar.gz

# 5. Copy code repository
tar -czf $MIGRATION_DIR/code.tar.gz \
    --exclude='node_modules' \
    --exclude='db/data' \
    --exclude='*.log' \
    .

# ============================================================
# TRANSFER TO NEW SERVER
# ============================================================
scp -r $MIGRATION_DIR user@new-server:~/migration/
# Hoặc dùng rsync cho file lớn:
# rsync -avzP $MIGRATION_DIR/ user@new-server:~/migration/

# ============================================================
# TRÊN SERVER MỚI: Import
# ============================================================
cd ~/migration

# 1. Extract code
mkdir -p /home/user/aw-visitor-docker
tar -xzf code.tar.gz -C /home/user/aw-visitor-docker/
cd /home/user/aw-visitor-docker

# 2. Restore .env
cp ~/migration/.env .

# 3. Tạo network
docker network create aw-visitor-network

# 4. Start database first
docker compose up -d postgres
sleep 15  # Wait for postgres

# 5. Restore database
zcat ~/migration/db.sql.gz | docker exec -i aw-visitor-postgres psql -U postgres -d visitor_db

# 6. Restore storage
tar -xzf ~/migration/storage.tar.gz

# 7. Start all services
docker compose up -d

# 8. Verify
docker compose ps
curl http://localhost:6201
```

---

## 7. Commands Reference

### Quick Reference Card

```bash
# ============================================================
# DATABASE COMMANDS
# ============================================================

# Backup database
docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db > backup.sql

# Backup với compression
docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db | gzip > backup.sql.gz

# Restore database
docker exec -i aw-visitor-postgres psql -U postgres -d visitor_db < backup.sql

# Restore từ gzip
zcat backup.sql.gz | docker exec -i aw-visitor-postgres psql -U postgres -d visitor_db

# Xem database size
docker exec -t aw-visitor-postgres psql -U postgres -c "
SELECT pg_size_pretty(pg_database_size('visitor_db'));
"

# List all tables
docker exec -t aw-visitor-postgres psql -U postgres -d visitor_db -c "\dt"

# ============================================================
# DOCKER COMMANDS
# ============================================================

# Xem status
docker compose ps

# Xem logs
docker compose logs -f                    # All services
docker compose logs -f backend            # Single service
docker compose logs --tail=100 backend    # Last 100 lines

# Restart single service
docker compose restart backend

# Rebuild và restart
docker compose up -d --build backend

# Xem resource usage
docker stats

# Clean up
docker system prune -f                    # Xóa unused data
docker volume prune -f                    # Xóa unused volumes
docker image prune -f                     # Xóa unused images

# ============================================================
# FILE OPERATIONS
# ============================================================

# Backup folder với tar
tar -czvf backup.tar.gz folder/

# Extract tar
tar -xzvf backup.tar.gz

# List contents without extracting
tar -tzvf backup.tar.gz

# Sync folders (incremental backup)
rsync -avz source/ destination/
```

### Crontab cho Automated Backup

```bash
# Edit crontab
crontab -e

# Thêm các dòng sau:
# ============================================================
# Backup database daily lúc 2:00 AM
0 2 * * * /home/gmo021/hienthan/aw-visitor-docker/scripts/backup-db.sh >> /var/log/backup.log 2>&1

# Backup storage weekly (Chủ nhật 3:00 AM)
0 3 * * 0 /home/gmo021/hienthan/aw-visitor-docker/scripts/backup-storage.sh >> /var/log/backup.log 2>&1

# Cleanup old backups daily lúc 4:00 AM
0 4 * * * find ~/backups/aw-visitor -name "db_*.sql.gz" -mtime +7 -delete
```

---

## Checklist trước khi Deploy

- [ ] Backup database đã xong
- [ ] Backup storage (nếu có thay đổi)
- [ ] Ghi lại current git commit
- [ ] Tag current Docker images
- [ ] Test restore procedure (định kỳ)
- [ ] Có đủ disk space cho backup mới
- [ ] Notification channel ready (Slack/Discord)

---

## Troubleshooting

### Database restore fails với "database in use"

```bash
# Terminate all connections trước khi drop
docker exec -t aw-visitor-postgres psql -U postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'visitor_db'
AND pid <> pg_backend_pid();
"
```

### Backup file bị corrupt

```bash
# Test gzip file integrity
gzip -t backup.sql.gz

# Nếu corrupt, thử recover partial data
gunzip -c backup.sql.gz > recovered.sql 2>/dev/null
```

### Disk full khi backup

```bash
# Check disk usage
df -h

# Compress trực tiếp (không tạo file .sql trước)
docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db | gzip > backup.sql.gz

# Backup to remote directly
docker exec -t aw-visitor-postgres pg_dump -U postgres visitor_db | gzip | ssh user@backup-server "cat > /backups/db.sql.gz"
```

