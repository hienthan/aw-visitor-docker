# Deployment Guide

## Access từ máy khác

```
Trên Server:  http://localhost:6201
Từ máy khác:  http://[SERVER_IP]:6201
```

## Checklist Deploy

### 1. Firewall

```bash
sudo ufw allow 6201/tcp
sudo ufw status
```

### 2. Build Code

```bash
# Frontend
cd aw-visitor
npm install
npm run build

# Backend
cd aw-visitor-backend-adonisjs
npm install
npm run build
```

### 3. Start Containers

```bash
# Database first
cd db && docker compose up -d && cd ..

# Then app
docker compose up -d
```

## Update Process

### Frontend Change

```bash
cd aw-visitor && npm run build
docker exec aw-visitor-frontend nginx -s reload
# Downtime: 0
```

### Backend Change

```bash
cd aw-visitor-backend-adonisjs && npm run build
docker compose restart backend
# Downtime: ~5-10 seconds
```

### Config Change

```bash
docker compose up -d --force-recreate
```

## Verify

```bash
# Check containers
docker compose ps

# Check logs
docker compose logs -f

# Test API
curl http://localhost:6201/api/visitor/testApi
```
