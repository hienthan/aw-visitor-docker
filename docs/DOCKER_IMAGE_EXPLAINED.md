# Docker Image Explained - node_modules từ đâu?

## Vấn đề thường gặp

**Câu hỏi:** Trên production server chỉ có build folder, không có node_modules. Docker copy kiểu gì?

**Trả lời:** node_modules nằm trong **Docker image**, không phải trong build folder!

## Docker Image là gì?

Docker image là một **template** chứa:
- Base OS (Alpine Linux trong trường hợp này)
- Node.js runtime
- **node_modules** (production dependencies)
- Build folder (có thể bị override bởi mount)

## Workflow đầy đủ

### 1. Build Docker Image (Lần đầu hoặc khi thay đổi dependencies)

```bash
# Trên máy dev hoặc CI/CD
docker compose build backend
```

**Điều gì xảy ra:**
1. Docker đọc `Dockerfile`
2. Copy `package.json` và `package-lock.json`
3. Chạy `npm ci --omit=dev` → Install production dependencies
4. Copy dependencies vào `/app/node_modules` trong image
5. Build image → `aw-visitor-backend:latest`

**Kết quả:** Image chứa `/app/node_modules` với tất cả dependencies

### 2. Deploy Image lên Production Server

**Option A: Push/Pull từ registry**
```bash
# Trên máy dev
docker tag aw-visitor-backend:latest registry.example.com/aw-visitor-backend:latest
docker push registry.example.com/aw-visitor-backend:latest

# Trên production server
docker pull registry.example.com/aw-visitor-backend:latest
```

**Option B: Save/Load image file**
```bash
# Trên máy dev
docker save aw-visitor-backend:latest | gzip > aw-visitor-backend-image.tar.gz

# Copy lên server và load
scp aw-visitor-backend-image.tar.gz user@server:/tmp/
ssh user@server "docker load < /tmp/aw-visitor-backend-image.tar.gz"
```

**Option C: Build trên server**
```bash
# Trên production server (cần có Dockerfile và package.json)
docker compose build backend
```

### 3. Deploy Build Folder

```bash
# Trên máy dev: Build code
./scripts/build-backend.sh

# Copy build folder lên server
scp -r aw-visitor-backend-adonisjs/build user@server:/path/to/aw-visitor-docker/aw-visitor-backend-adonisjs/

# Trên server: Deploy
./scripts/deploy-production.sh
```

## Cấu trúc trong Container

Khi container chạy, Docker **merge** image và mount:

```
Container: /app/
├── node_modules/     ← Từ Docker image (built khi build image)
│   ├── @adonisjs/core/
│   ├── pg/
│   └── ... (tất cả dependencies)
│
├── build/            ← Mount từ host (code đã compile)
│   ├── bin/server.js
│   ├── app/
│   ├── config/
│   └── storage/
│       └── app/     ← Mount từ shared-storage
```

## Tại sao cần Image?

1. **node_modules phụ thuộc vào OS/Architecture**
   - Linux x64 khác với macOS ARM
   - Dependencies native modules cần compile cho đúng platform
   - Image đảm bảo consistency

2. **Performance**
   - node_modules lớn (~100MB+)
   - Không cần copy mỗi lần deploy
   - Chỉ cần build image khi thay đổi dependencies

3. **Separation of Concerns**
   - Dependencies (image) vs Code (build folder)
   - Update code nhanh không cần rebuild image
   - Update dependencies → rebuild image

## Checklist Production Deploy

### Lần đầu setup:
- [ ] Build Docker image: `docker compose build backend`
- [ ] Push/Save image lên server
- [ ] Copy build folder lên server
- [ ] Run deploy script

### Update code (thường xuyên):
- [ ] Build code: `./scripts/build-backend.sh`
- [ ] Copy build folder lên server
- [ ] Run deploy script: `./scripts/deploy-production.sh`

### Update dependencies (ít khi):
- [ ] Update `package.json`
- [ ] Build image: `docker compose build backend`
- [ ] Push/Save image lên server
- [ ] Restart container

## Troubleshooting

### Lỗi: "Cannot find module 'xxx'"
**Nguyên nhân:** Dependencies mới chưa có trong image

**Giải pháp:**
```bash
# Rebuild image với dependencies mới
docker compose build backend
```

### Lỗi: "Image not found"
**Nguyên nhân:** Image chưa được build hoặc chưa được load lên server

**Giải pháp:**
```bash
# Check image
docker images | grep aw-visitor-backend

# Build nếu chưa có
docker compose build backend
```

### Lỗi: "Container failed to start"
**Xem logs:**
```bash
docker compose logs -f backend
# hoặc
docker logs aw-visitor-backend
```

## Tóm tắt

- ✅ **node_modules** → Trong Docker image (build một lần)
- ✅ **build folder** → Mount từ host (update thường xuyên)
- ✅ **Image** → Chứa dependencies, base OS, runtime
- ✅ **Container** → Merge image + mount = có cả node_modules và build folder

**Trên production server:**
1. Cần có Docker image (chứa node_modules)
2. Cần có build folder (code đã compile)
3. Docker tự động merge khi container chạy

