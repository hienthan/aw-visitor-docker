# Docker Image Management - Best Practices

## Vấn đề với Build trên Server

Build Docker image trên server có nhiều vấn đề:
- ❌ Cần source code, node_modules, build tools
- ❌ Tốn tài nguyên server
- ❌ Dễ lỗi (missing files, permission issues)
- ❌ Khó debug khi lỗi
- ❌ Chậm (server thường yếu hơn máy dev)

## Giải pháp: Build trên Dev, Save/Load lên Server

### Workflow

**Trên máy dev:**
1. Build image
2. Save image thành file
3. Copy file lên server

**Trên server:**
1. Load image từ file
2. Deploy code (build folder)

## Scripts

### 1. Build and Save (Trên máy dev)

```bash
./scripts/build-and-save-image.sh
```

**Làm gì:**
- Build Docker image: `aw-visitor-backend:latest`
- Save image thành file: `docker-images/aw-visitor-backend_latest.tar.gz`

### 2. Save Image (Nếu đã có image)

```bash
./scripts/save-image.sh [IMAGE_NAME] [OUTPUT_DIR]
```

**Ví dụ:**
```bash
./scripts/save-image.sh aw-visitor-backend:latest
./scripts/save-image.sh aw-visitor-backend:v1.0.0 /custom/path
```

### 3. Load Image (Trên server)

```bash
./scripts/load-image.sh [IMAGE_FILE]
```

**Ví dụ:**
```bash
./scripts/load-image.sh docker-images/aw-visitor-backend_latest.tar.gz
```

## Cấu trúc thư mục trên Server

**Recommended structure:**
```
/opt/docker-images/          # Central location cho tất cả images
├── aw-visitor/
│   └── aw-visitor-backend_latest.tar.gz
├── app2/
│   └── app2-backend_latest.tar.gz
└── app3/
    └── app3-backend_latest.tar.gz
```

**Hoặc trong project:**
```
aw-visitor-docker/
├── docker-images/           # Local images cho project này
│   └── aw-visitor-backend_latest.tar.gz
└── ...
```

## Workflow đầy đủ

### Lần đầu setup (hoặc khi thay đổi dependencies)

**Trên máy dev:**
```bash
# 1. Build và save image
./scripts/build-and-save-image.sh

# 2. Copy image lên server
scp docker-images/aw-visitor-backend_latest.tar.gz user@server:/opt/docker-images/aw-visitor/
```

**Trên server:**
```bash
# 3. Load image
export DOCKER_IMAGES_DIR=/opt/docker-images/aw-visitor
./scripts/load-image.sh

# Hoặc chỉ định file cụ thể
./scripts/load-image.sh /opt/docker-images/aw-visitor/aw-visitor-backend_latest.tar.gz
```

### Update code (thường xuyên)

**Trên máy dev:**
```bash
# 1. Build code
./scripts/build-backend.sh

# 2. Copy build folder lên server
scp -r aw-visitor-backend-adonisjs/build user@server:/path/to/aw-visitor-docker/aw-visitor-backend-adonisjs/
```

**Trên server:**
```bash
# 3. Deploy
./scripts/deploy-production.sh
```

## Quản lý nhiều Apps

### Option 1: Central Images Directory

```bash
# Tạo thư mục chung
sudo mkdir -p /opt/docker-images
sudo chown $USER:$USER /opt/docker-images

# Mỗi app có subfolder
/opt/docker-images/
├── aw-visitor/
│   └── aw-visitor-backend_latest.tar.gz
├── user-management/
│   └── user-backend_latest.tar.gz
└── reporting/
    └── report-backend_latest.tar.gz
```

**Load image:**
```bash
export DOCKER_IMAGES_DIR=/opt/docker-images/aw-visitor
./scripts/load-image.sh
```

### Option 2: Per-Project Images

Mỗi project có thư mục `docker-images/` riêng:
```
project1/
├── docker-images/
│   └── image1.tar.gz
└── ...

project2/
├── docker-images/
│   └── image2.tar.gz
└── ...
```

## Best Practices

### 1. Versioning Images

```bash
# Save với version
./scripts/save-image.sh aw-visitor-backend:v1.0.0
./scripts/save-image.sh aw-visitor-backend:latest

# File sẽ là:
# aw-visitor-backend_v1.0.0.tar.gz
# aw-visitor-backend_latest.tar.gz
```

### 2. Backup Images

```bash
# Backup trước khi update
cp docker-images/aw-visitor-backend_latest.tar.gz \
   docker-images/aw-visitor-backend_latest.backup.$(date +%Y%m%d).tar.gz
```

### 3. Cleanup Old Images

```bash
# Xóa images cũ (giữ lại 5 bản mới nhất)
cd docker-images
ls -t *.tar.gz | tail -n +6 | xargs rm -f
```

### 4. Verify Image

```bash
# Sau khi load, verify
docker images | grep aw-visitor-backend
docker inspect aw-visitor-backend:latest
```

## Troubleshooting

### Lỗi: "Cannot find module '/app/ace'"
**Nguyên nhân:** Dockerfile build stage thiếu file hoặc command sai

**Giải pháp:** Đã fix trong Dockerfile - dùng `node ace.js build`

### Lỗi: "Image not found" khi load
**Nguyên nhân:** File bị corrupt hoặc không đúng format

**Giải pháp:**
```bash
# Verify file
file image.tar.gz
# Should show: gzip compressed data

# Try extract để test
gunzip -t image.tar.gz
```

### Lỗi: "No space left on device"
**Nguyên nhân:** Disk đầy

**Giải pháp:**
```bash
# Cleanup old images
docker image prune -a

# Check disk space
df -h
```

## Tóm tắt

✅ **Build trên máy dev** → Nhanh, dễ debug, không tốn tài nguyên server
✅ **Save/Load images** → Đơn giản, không cần registry
✅ **Central images directory** → Dễ quản lý nhiều apps
✅ **Versioning** → Dễ rollback nếu cần

**Workflow:**
1. Dev: Build → Save → Copy
2. Server: Load → Deploy code
3. Repeat khi update code (không cần rebuild image)

