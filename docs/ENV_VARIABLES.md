# Environment Variables Guide

## Tổng quan

Các scripts sử dụng environment variables để cấu hình linh hoạt. Bạn có thể set trước khi chạy script hoặc export trong shell.

## Environment Variables

### 1. DOCKER_IMAGE_NAME

**Mục đích:** Tên Docker image để sử dụng

**Default:** `aw-visitor-backend`

**Sử dụng trong:**
- `deploy-production.sh` - Chỉ định image name khi deploy

**Ví dụ:**
```bash
# Sử dụng image name mặc định
./scripts/deploy-production.sh

# Sử dụng image name khác
DOCKER_IMAGE_NAME=my-app-backend ./scripts/deploy-production.sh
```

**Khi nào cần thay đổi:**
- Khi có nhiều backend services trong cùng project
- Khi muốn dùng image name khác với default

---

### 2. DOCKER_IMAGE_VERSION

**Mục đích:** Version/tag của Docker image

**Default:** `latest`

**Sử dụng trong:**
- `deploy-production.sh` - Chỉ định image version khi deploy

**Ví dụ:**
```bash
# Sử dụng latest (default)
./scripts/deploy-production.sh

# Sử dụng version cụ thể
DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh

# Hoặc version khác
DOCKER_IMAGE_VERSION=1.2.3 ./scripts/deploy-production.sh
```

**Khi nào cần thay đổi:**
- Khi deploy version cụ thể thay vì latest
- Khi rollback về version cũ
- Khi test version mới trước khi chuyển sang latest

---

### 3. DOCKER_IMAGES_DIR

**Mục đích:** Thư mục chứa Docker image files trên server

**Default:** `$PROJECT_ROOT/docker-images` (trong project)

**Sử dụng trong:**
- `load-image.sh` - Tìm image file nếu không chỉ định path

**Ví dụ:**
```bash
# Sử dụng default (docker-images trong project)
./scripts/load-image.sh

# Sử dụng central directory
export DOCKER_IMAGES_DIR=/home/ps/docker-images
./scripts/load-image.sh

# Hoặc chỉ định file cụ thể (không cần env var)
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v1.0.0.tar.gz
```

**Khi nào cần thay đổi:**
- Khi muốn dùng central images directory cho nhiều apps
- Khi images nằm ở vị trí khác với default

---

### 4. SHARED_STORAGE_PATH

**Mục đích:** Đường dẫn đến shared storage folder

**Default:** `../shared-storage`

**Sử dụng trong:**
- `docker-compose.yml` - Mount shared storage vào container

**Ví dụ:**
```bash
# Sử dụng default
docker compose up -d

# Sử dụng path khác
SHARED_STORAGE_PATH=/opt/shared-storage docker compose up -d
```

**Khi nào cần thay đổi:**
- Khi shared storage ở vị trí khác
- Khi deploy trên server với cấu trúc khác

---

## Cách sử dụng

### Option 1: Export trong shell session

```bash
# Set cho session hiện tại
export DOCKER_IMAGE_VERSION=v1.0.0
export DOCKER_IMAGES_DIR=/home/ps/docker-images

# Chạy scripts (sẽ dùng env vars đã set)
./scripts/deploy-production.sh
./scripts/load-image.sh
```

### Option 2: Set trước khi chạy command

```bash
# Set chỉ cho command đó
DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh

# Hoặc nhiều vars
DOCKER_IMAGE_NAME=aw-visitor-backend DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh
```

### Option 3: Tạo .env file (cho docker-compose)

```bash
# Tạo .env trong project root
cat > .env << EOF
DOCKER_IMAGE_VERSION=v1.0.0
SHARED_STORAGE_PATH=/opt/shared-storage
EOF

# docker-compose sẽ tự động đọc
docker compose up -d
```

### Option 4: Tạo config script

```bash
# Tạo scripts/config.sh
#!/bin/bash
export DOCKER_IMAGE_NAME=aw-visitor-backend
export DOCKER_IMAGE_VERSION=v1.0.0
export DOCKER_IMAGES_DIR=/home/ps/docker-images
export SHARED_STORAGE_PATH=/opt/shared-storage

# Source trước khi chạy scripts
source scripts/config.sh
./scripts/deploy-production.sh
```

## Workflow với Env Variables

### Production Server Setup

**Tạo config file trên server:**
```bash
# ~/.aw-visitor-config
export DOCKER_IMAGE_NAME=aw-visitor-backend
export DOCKER_IMAGES_DIR=/home/ps/docker-images
export SHARED_STORAGE_PATH=/opt/shared-storage
```

**Sử dụng:**
```bash
# Load config
source ~/.aw-visitor-config

# Deploy với version cụ thể
DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh
```

### Deploy với Version cụ thể

```bash
# 1. Load image với version
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v1.0.0.tar.gz

# 2. Deploy với version đó
DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh
```

### Rollback về Version cũ

```bash
# 1. Load version cũ
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v0.9.0.tar.gz

# 2. Deploy với version cũ
DOCKER_IMAGE_VERSION=v0.9.0 ./scripts/deploy-production.sh
```

## Docker Images sau khi Load

### Image được lưu ở đâu?

**Sau khi load image:**
```bash
docker load < image.tar.gz
```

**Image được lưu trong Docker:**
- Location: `/var/lib/docker/image/` (Docker internal)
- Không cần quan tâm path cụ thể
- Docker tự quản lý

**Xem images đã load:**
```bash
docker images
# REPOSITORY              TAG       IMAGE ID       CREATED         SIZE
# aw-visitor-backend      v1.0.0    abc123def456   2 hours ago     262MB
# aw-visitor-backend      latest    abc123def456   2 hours ago     262MB
```

**Docker sẽ tự động tìm image khi:**
- `docker compose up` - Tìm theo tên trong docker-compose.yml
- `docker run aw-visitor-backend:v1.0.0` - Tìm theo tên:tag

### Image Files vs Loaded Images

**Image files (.tar.gz):**
- Lưu ở: `/home/ps/docker-images/` (hoặc nơi bạn chỉ định)
- Format: `aw-visitor-backend_v1.0.0.tar.gz`
- Dùng để: Copy giữa các máy, backup

**Loaded images:**
- Lưu trong Docker daemon
- Xem bằng: `docker images`
- Dùng để: Chạy containers

**Workflow:**
1. Load image từ file → Docker daemon
2. Docker compose tìm image trong daemon
3. Container chạy từ image trong daemon

## Best Practices

### 1. Luôn set version khi deploy production

```bash
# ✅ Good
DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh

# ❌ Bad (dùng latest có thể không đúng version)
./scripts/deploy-production.sh
```

### 2. Tạo config file trên server

```bash
# ~/.aw-visitor-config
export DOCKER_IMAGE_NAME=aw-visitor-backend
export DOCKER_IMAGES_DIR=/home/ps/docker-images
```

### 3. Document versions

```bash
# Ghi lại version đang dùng
echo "Current version: v1.0.0" > .current-version
```

### 4. Verify sau khi load

```bash
# Check image đã load
docker images | grep aw-visitor-backend

# Verify version
docker inspect aw-visitor-backend:v1.0.0
```

## Troubleshooting

### Image không tìm thấy

```bash
# Check images đã load
docker images | grep aw-visitor-backend

# Nếu không có, load lại
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v1.0.0.tar.gz
```

### Version không đúng

```bash
# Check version hiện tại
docker images | grep aw-visitor-backend

# Set version đúng
export DOCKER_IMAGE_VERSION=v1.0.0
./scripts/deploy-production.sh
```

### Env variable không được nhận

```bash
# Check env var
echo $DOCKER_IMAGE_VERSION

# Set lại
export DOCKER_IMAGE_VERSION=v1.0.0
```

## Tóm tắt

| Variable | Default | Mục đích | Khi nào cần thay đổi |
|----------|---------|----------|---------------------|
| `DOCKER_IMAGE_NAME` | `aw-visitor-backend` | Tên image | Nhiều services |
| `DOCKER_IMAGE_VERSION` | `latest` | Version image | Deploy version cụ thể |
| `DOCKER_IMAGES_DIR` | `./docker-images` | Thư mục images | Central directory |
| `SHARED_STORAGE_PATH` | `../shared-storage` | Shared storage path | Path khác |

**Workflow:**
1. Set env vars (export hoặc inline)
2. Load image: `./scripts/load-image.sh`
3. Deploy: `DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh`

