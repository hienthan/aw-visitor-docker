# AW-Visitor Docker Setup

Self-contained Docker setup cho Visitor Management System.

## Quick Start

```bash
# 1. Start Database
cd db && docker compose up -d && cd ..

# 2. Start Application
docker compose up -d

# 3. Verify
docker compose ps
```

## Access

| Service | URL |
|---------|-----|
| Frontend | http://localhost:6201 |
| Frontend (LAN) | http://[SERVER_IP]:6201 |
| Database | localhost:7201 |

## Update Code

```bash
# Frontend
cd aw-visitor && npm run build
docker exec aw-visitor-frontend nginx -s reload

# Backend - Quick update (chỉ code, không rebuild image)
./scripts/build-backend.sh
docker compose restart backend

# Backend - Full deploy (code + rebuild image)
./scripts/deploy.sh

# Xem chi tiết: docs/BACKEND_DEPLOYMENT.md
```

## Backup

```bash
# Database
docker exec aw-visitor-postgres pg_dump -U postgres visitor_db > backup.sql

# Storage
tar -czvf storage_backup.tar.gz aw-visitor-backend-adonisjs/storage/
```

## Ports

| Service | Internal | External |
|---------|----------|----------|
| Frontend | 80 | 6201 |
| Backend | 3333 | - |
| Database | 5432 | 7201 |

## Documentation

- [Docker Learning Guide](docs/DOCKER_GUIDE.md) - Chi tiết về Docker concepts và commands
- [Deployment Guide](docs/DEPLOYMENT.md) - Hướng dẫn deploy

## File Structure

```
aw-visitor-docker/
├── docker-compose.yml        # App services (fully commented)
├── .env                      # Environment variables
├── .env.example              # Template
├── .gitignore                # Git ignore rules
├── README.md                 # Quick reference
│
├── db/
│   ├── docker-compose.yml    # Database (fully commented)
│   └── data/                 # PostgreSQL data (git ignored)
│
├── nginx/
│   └── aw-visitor.conf       # Nginx routing
│
├── docs/
│   ├── DOCKER_GUIDE.md       # ⭐ Chi tiết Docker concepts, commands, rollback
│   ├── DEPLOYMENT.md         # Deployment checklist
│   └── BACKEND_DEPLOYMENT.md # Backend deployment best practices
│
├── scripts/
│   ├── build-backend.sh         # Build backend code
│   ├── deploy.sh                # Full deploy (local - build + image + restart)
│   ├── deploy-production.sh      # Production deploy (chỉ restart với build folder)
│   ├── build-and-save-image.sh  # Build và save image để deploy
│   ├── save-image.sh            # Save Docker image thành file
│   └── load-image.sh            # Load Docker image từ file
│
├── aw-visitor/               # Frontend
│   └── dist/                 # (git ignored - rebuild được)
│
└── aw-visitor-backend-adonisjs/
    ├── build/                # (git ignored - rebuild được)
    └── storage/              # Uploaded files (git ignored - backup riêng)
```
