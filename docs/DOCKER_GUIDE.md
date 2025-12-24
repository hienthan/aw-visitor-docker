# Docker Learning Guide

## Mục lục

1. [Cấu trúc Project](#cấu-trúc-project)
2. [Docker Concepts](#docker-concepts)
3. [Commands Thường Dùng](#commands-thường-dùng)
4. [Workflow Cập Nhật Code](#workflow-cập-nhật-code)
5. [Deployment Process](#deployment-process)
6. [Rollback & Backup](#rollback--backup)

---

## Cấu trúc Project

### Tại sao mỗi app có folder riêng?

```
# ✅ ĐÚNG: Mỗi app self-contained
/projects/
├── aw-visitor-docker/           # App 1 - hoàn toàn độc lập
│   ├── docker-compose.yml
│   ├── db/
│   ├── nginx/
│   └── ...
├── user-management-docker/      # App 2 - hoàn toàn độc lập
│   ├── docker-compose.yml
│   └── ...
└── another-app-docker/          # App 3
    └── ...

# ❌ SAI: Gom chung
/projects/
├── docker-compose.yml           # Quản lý tất cả apps
├── app1/
├── app2/
└── db/                          # Database dùng chung
```

**Lý do:**
- Move 1 app sang máy khác → chỉ copy 1 folder
- App crash không ảnh hưởng apps khác
- Dễ version control riêng
- Dễ rollback từng app

### Cấu trúc chuẩn cho mỗi app

```
app-docker/
├── docker-compose.yml        # Main compose file
├── .env                      # Environment variables (không commit)
├── .env.example              # Template cho .env
├── .gitignore
│
├── db/
│   ├── docker-compose.yml    # Database riêng
│   └── data/                 # PostgreSQL data (bind mount)
│
├── nginx/
│   └── app.conf              # Nginx config
│
├── storage/                  # Uploaded files
│   └── ...
│
├── frontend/                 # Frontend source + dist
│   └── dist/
│
├── backend/                  # Backend source + build
│   ├── build/
│   └── node_modules/
│
└── docs/                     # Documentation
```

---

## Docker Concepts

### Image vs Container

```
Image = Template (read-only)
Container = Running instance của Image

Ví dụ:
- Image: node:22-alpine (download từ Docker Hub)
- Container: aw-visitor-backend (running instance)

1 Image → nhiều Containers
```

### Volumes: Bind Mount vs Named Volume

```yaml
volumes:
  # Bind Mount: Map folder từ host
  - ./data:/var/lib/postgresql/data
  # Ưu điểm: Dễ backup, dễ access từ host
  # Nhược điểm: Phụ thuộc vào path trên host

  # Named Volume: Docker quản lý
  - postgres_data:/var/lib/postgresql/data
  # Ưu điểm: Performance tốt hơn, portable
  # Nhược điểm: Khó access, backup phức tạp hơn
```

**Khi nào dùng gì:**
- Bind Mount: Data cần backup thường xuyên, cần access từ host
- Named Volume: Data không cần access trực tiếp, cần performance

### Network Modes

```yaml
networks:
  app-network:
    driver: bridge      # Default, recommended
    # driver: host      # Dùng network của host (không isolation)
    # driver: none      # Không có network
```

**Bridge network:**
- Containers giao tiếp qua container name
- Isolated từ host network
- Có thể expose ports cụ thể

### Restart Policies

```yaml
restart: "no"              # Không restart (default)
restart: always            # Luôn restart, kể cả stop thủ công
restart: unless-stopped    # Restart trừ khi stop thủ công ✅
restart: on-failure        # Chỉ restart khi crash (exit != 0)
```

**Recommended: `unless-stopped`**
- Auto restart khi crash hoặc reboot server
- Không restart khi stop thủ công để maintenance

---

## Commands Thường Dùng

### Lifecycle Commands

```bash
# Start services (background)
docker compose up -d

# Stop services
docker compose down

# Stop + remove volumes (XÓA DATA!)
docker compose down -v

# Restart specific service
docker compose restart backend

# Rebuild và restart
docker compose up -d --build backend
```

### Viewing Commands

```bash
# Xem running containers
docker compose ps

# Xem logs (follow)
docker compose logs -f

# Logs của 1 service
docker compose logs -f backend

# Logs 100 dòng cuối
docker compose logs --tail 100 backend
```

### Debugging Commands

```bash
# Vào container
docker exec -it aw-visitor-backend sh

# Chạy command trong container
docker exec aw-visitor-backend ls /app

# Xem resource usage
docker stats

# Xem container details
docker inspect aw-visitor-backend

# Xem network
docker network inspect aw-visitor-network
```

### Cleanup Commands

```bash
# Xóa containers đã stop
docker container prune

# Xóa images không dùng
docker image prune

# Xóa tất cả không dùng (cẩn thận!)
docker system prune -a
```

---

## Workflow Cập Nhật Code

### Frontend Update

```bash
# 1. Build frontend (trên máy dev hoặc server)
cd aw-visitor
npm run build

# 2. Reload nginx (không cần restart container)
docker exec aw-visitor-frontend nginx -s reload

# Thời gian: < 1 giây, không downtime
```

### Backend Update

```bash
# 1. Build backend
cd aw-visitor-backend-adonisjs
npm run build

# 2. Restart container
docker compose restart backend

# Thời gian: ~5-10 giây, có downtime ngắn
```

### Zero-Downtime Update (Advanced)

Để không có downtime khi update backend:

```bash
# Option 1: Rolling update với replicas
# Cần modify docker-compose.yml để dùng deploy.replicas

# Option 2: Blue-Green deployment
# Chạy container mới trên port khác, switch nginx khi ready

# Option 3: Dùng Docker Swarm hoặc Kubernetes
# Tự động rolling update
```

### Config Changes

```bash
# Khi thay đổi docker-compose.yml
docker compose up -d --force-recreate

# Khi thay đổi nginx config
docker exec aw-visitor-frontend nginx -s reload

# Khi thay đổi .env
docker compose up -d --force-recreate
```

---

## Deployment Process

### Process chuẩn khi Dev push code mới

```
┌─────────────────────────────────────────────────────────────┐
│                    DEV PUSHES CODE                           │
│                          │                                   │
│                          ▼                                   │
│   ┌─────────────────────────────────────────────────────┐   │
│   │                   DEVOPS                             │   │
│   │                                                      │   │
│   │  1. git pull                                         │   │
│   │  2. Build (npm run build)                            │   │
│   │  3. Restart container hoặc reload                    │   │
│   │                                                      │   │
│   └─────────────────────────────────────────────────────┘   │
│                          │                                   │
│                          ▼                                   │
│                   APP UPDATED                                │
│                                                              │
│   Thời gian:                                                │
│   - Frontend: < 1 giây (nginx reload)                       │
│   - Backend: 5-10 giây (container restart)                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Commands tóm tắt

```bash
# Frontend update
cd aw-visitor && npm run build
docker exec aw-visitor-frontend nginx -s reload

# Backend update
cd aw-visitor-backend-adonisjs && npm run build
docker compose restart backend

# Cả 2
cd aw-visitor && npm run build
cd ../aw-visitor-backend-adonisjs && npm run build
docker compose restart backend
docker exec aw-visitor-frontend nginx -s reload
```

---

## Rollback & Backup

### Backup Strategy

#### 1. Database Backup

```bash
# Backup database to SQL file
docker exec aw-visitor-postgres pg_dump -U postgres visitor_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup với compression
docker exec aw-visitor-postgres pg_dump -U postgres visitor_db | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Hoặc copy folder data (khi container STOP)
docker compose -f db/docker-compose.yml stop
cp -r db/data db/data_backup_$(date +%Y%m%d)
docker compose -f db/docker-compose.yml start
```

#### 2. Restore Database

```bash
# Restore từ SQL file
cat backup_20251223.sql | docker exec -i aw-visitor-postgres psql -U postgres visitor_db

# Restore từ gzip
gunzip -c backup_20251223.sql.gz | docker exec -i aw-visitor-postgres psql -U postgres visitor_db

# Restore từ folder backup
docker compose -f db/docker-compose.yml down
rm -rf db/data
cp -r db/data_backup_20251223 db/data
docker compose -f db/docker-compose.yml up -d
```

#### 3. Storage Backup (Uploaded Files)

```bash
# Backup storage folder
tar -czvf storage_backup_$(date +%Y%m%d).tar.gz aw-visitor-backend-adonisjs/storage/

# Restore
tar -xzvf storage_backup_20251223.tar.gz
```

### Rollback Strategy

#### Code Rollback (Git-based)

```bash
# Xem history
git log --oneline -10

# Rollback về commit cụ thể
git checkout <commit_hash> -- aw-visitor/
git checkout <commit_hash> -- aw-visitor-backend-adonisjs/

# Rebuild
cd aw-visitor && npm run build
cd ../aw-visitor-backend-adonisjs && npm run build

# Restart
docker compose restart backend
docker exec aw-visitor-frontend nginx -s reload
```

#### Container Rollback

```bash
# Nếu container mới bị lỗi, restart với code cũ
# (Sau khi đã git checkout về version cũ)

docker compose down
docker compose up -d
```

#### Database Rollback

```bash
# CẢNH BÁO: Sẽ mất data mới từ lúc backup
docker compose -f db/docker-compose.yml down
rm -rf db/data
cp -r db/data_backup_YYYYMMDD db/data
docker compose -f db/docker-compose.yml up -d
```

### Best Practices

1. **Backup trước khi update**

```bash
# Script backup trước deploy
docker exec aw-visitor-postgres pg_dump -U postgres visitor_db > pre_deploy_$(date +%Y%m%d_%H%M%S).sql
```

2. **Test trên staging trước**

```bash
# Clone project sang folder khác
cp -r aw-visitor-docker aw-visitor-staging
# Đổi ports trong .env
# Test
```

3. **Giữ N bản backup**

```bash
# Giữ 7 bản backup gần nhất
ls -t backup_*.sql | tail -n +8 | xargs rm -f
```

