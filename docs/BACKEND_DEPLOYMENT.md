# Backend Deployment Guide

## Tổng quan

Backend được cấu hình để:
- **node_modules**: Nằm trong Docker image (không mount từ host)
- **build folder**: Mount từ host để update code nhanh không cần rebuild image
- **storage**: Mount từ shared storage ra ngoài

### Build folder có đủ thông tin chưa?

**Có!** Build folder đã chứa đầy đủ:
- ✅ Code đã compile (JavaScript từ TypeScript)
- ✅ Config files đã compile
- ✅ Routes, controllers, models đã compile
- ✅ Entry point: `bin/server.js`

**Không cần:**
- ❌ Source code TypeScript (đã compile rồi)
- ❌ package.json (dependencies đã có trong Docker image)
- ❌ node_modules (đã có trong Docker image)
- ❌ tsconfig.json (chỉ cần khi build)

### node_modules ở đâu?

**node_modules nằm trong Docker image**, không cần trong build folder:

```
Container structure:
/app/
├── node_modules/     ← Từ Docker image (built khi build image)
├── build/            ← Mount từ host (code đã compile)
│   ├── bin/server.js
│   ├── app/
│   └── config/
```

**Workflow:**
1. Build Docker image → node_modules được copy vào image tại `/app/node_modules`
2. Mount build folder từ host → `/app/build` (code đã compile)
3. Container chạy → Có cả node_modules (từ image) và build (từ host)

**Vì vậy, trên production server chỉ cần build folder là đủ!**

## Cấu trúc trong Container

```
/app/
├── node_modules/          # Từ Docker image (production dependencies)
├── build/                 # Mount từ host (code đã compile)
│   ├── bin/
│   │   └── server.js     # Entry point
│   ├── app/
│   ├── config/
│   └── storage/
│       └── app/          # Mount từ shared-storage
```

## Workflow Deploy

### 1. Development (Local)

```bash
# Build code
cd aw-visitor-backend-adonisjs
npm ci
npm run build

# Start containers
cd ..
docker compose up -d
```

### 2. Production Deploy

#### Workflow Production (Máy chủ chỉ có build folder)

**⚠️ QUAN TRỌNG:** Trên production server cần có **Docker image** trước!

**Lần đầu setup (hoặc khi thay đổi dependencies):**
```bash
# 1. Build Docker image (chứa node_modules)
docker compose build backend

# 2. Push/Save image lên server (nếu build trên máy khác)
docker save aw-visitor-backend:latest | gzip > aw-visitor-backend-image.tar.gz
scp aw-visitor-backend-image.tar.gz user@server:/tmp/
ssh user@server "docker load < /tmp/aw-visitor-backend-image.tar.gz"
```

**Deploy code (thường xuyên):**
```bash
# Trên máy dev:
# 1. Build code
./scripts/build-backend.sh

# 2. Copy build folder lên server
scp -r aw-visitor-backend-adonisjs/build user@server:/path/to/aw-visitor-docker/aw-visitor-backend-adonisjs/

# Trên máy chủ:
# 3. Deploy và restart
./scripts/deploy-production.sh

# Hoặc nếu build folder ở vị trí khác:
./scripts/deploy-production.sh /path/to/build
```

**Xem logs khi lỗi:**
```bash
docker compose logs -f backend
# hoặc
docker logs aw-visitor-backend
```

#### Option A: Full Deploy (Local - có source code)

```bash
# Build code + rebuild image + restart
./scripts/deploy.sh
```

#### Option B: Quick Update (Local - chỉ code)

```bash
# 1. Build code
./scripts/build-backend.sh

# 2. Restart container
docker compose restart backend
```

#### Option C: Chỉ rebuild image (code không đổi)

```bash
# Rebuild image với code hiện tại
docker compose build backend
docker compose up -d --no-deps backend
```

## Khi nào cần rebuild image?

**Cần rebuild image khi:**
- ✅ Thay đổi `package.json` (thêm/xóa dependencies)
- ✅ Thay đổi Dockerfile
- ✅ Thay đổi environment variables mặc định trong Dockerfile

**KHÔNG cần rebuild image khi:**
- ✅ Chỉ thay đổi code TypeScript/JavaScript
- ✅ Chỉ update code trong `app/`, `config/`, `start/`
- ✅ Thay đổi environment variables trong docker-compose.yml

## Best Practices

### 1. Dependencies Management

```bash
# Khi thêm dependency mới:
cd aw-visitor-backend-adonisjs
npm install <package>
npm run build
cd ..
docker compose build backend  # Rebuild image với dependencies mới
docker compose up -d --no-deps backend
```

### 2. Code Updates

```bash
# Chỉ cần build code và restart:
./scripts/build-backend.sh
docker compose restart backend
```

### 3. Troubleshooting

**Lỗi: Module not found**
- Nguyên nhân: Dependencies mới chưa được install trong image
- Giải pháp: Rebuild image với `docker compose build backend`

**Lỗi: Code không update**
- Nguyên nhân: Build folder chưa được build hoặc mount sai
- Giải pháp: 
  ```bash
  ./scripts/build-backend.sh
  docker compose restart backend
  ```

**Lỗi: node_modules conflict**
- Nguyên nhân: node_modules từ host bị mount vào (không nên)
- Giải pháp: Đảm bảo chỉ mount `build/` folder, không mount toàn bộ backend folder

## Migration từ cấu hình cũ

Nếu bạn đang dùng cấu hình cũ (mount toàn bộ backend folder):

1. **Backup code hiện tại**
   ```bash
   cp -r aw-visitor-backend-adonisjs aw-visitor-backend-adonisjs.backup
   ```

2. **Build code lần đầu**
   ```bash
   ./scripts/build-backend.sh
   ```

3. **Build Docker image**
   ```bash
   docker compose build backend
   ```

4. **Restart với cấu hình mới**
   ```bash
   docker compose up -d --no-deps backend
   ```

5. **Verify**
   ```bash
   docker compose logs backend
   docker compose exec backend ls -la /app
   # Should see: node_modules/ và build/
   ```

## File Structure

```
aw-visitor-backend-adonisjs/
├── Dockerfile              # Multi-stage build
├── package.json
├── tsconfig.json
├── app/                    # Source code
├── config/
├── start/
├── build/                  # Compiled output (git ignored)
│   ├── bin/server.js
│   └── ...
└── node_modules/          # Dependencies (git ignored, trong image)
```

## Environment Variables

Environment variables được set trong `docker-compose.yml`, không hardcode trong Dockerfile (trừ các giá trị mặc định không nhạy cảm).

Xem `docker-compose.yml` section `backend.environment` để thay đổi config.

