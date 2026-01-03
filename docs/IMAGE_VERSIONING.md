# Docker Image Versioning Guide

## Docker Image Tags là gì?

Docker image có format: `IMAGE_NAME:TAG`

**Ví dụ:**
- `aw-visitor-backend:latest` - Image name là `aw-visitor-backend`, tag là `latest`
- `aw-visitor-backend:v1.0.0` - Image name là `aw-visitor-backend`, tag là `v1.0.0`
- `aw-visitor-backend:1.2.3` - Image name là `aw-visitor-backend`, tag là `1.2.3`

## :latest có nghĩa gì?

`:latest` là **tag mặc định** của Docker, không có ý nghĩa đặc biệt:
- ✅ Chỉ là một tag như các tag khác
- ✅ Không tự động update khi có image mới
- ✅ Không đảm bảo là version mới nhất
- ✅ Chỉ là convention để chỉ "version hiện tại"

**Best practice:** Luôn tag với version cụ thể, và cũng tag `latest` để tiện.

## Workflow với Versioning

### 1. Build và Save Image với Version

**Trên máy dev:**
```bash
# Build và save với version cụ thể
./scripts/build-and-save-image.sh v1.0.0

# Kết quả:
# - docker-images/aw-visitor-backend_v1.0.0.tar.gz
# - docker-images/aw-visitor-backend_latest.tar.gz (auto-tagged)
```

**Script sẽ:**
1. Build image: `aw-visitor-backend:latest`
2. Tag với version: `aw-visitor-backend:v1.0.0`
3. Save cả 2 versions

### 2. Copy lên Server

```bash
# Copy image với version
scp docker-images/aw-visitor-backend_v1.0.0.tar.gz ps@10.1.16.50:/home/ps/docker-images/

# Hoặc copy latest
scp docker-images/aw-visitor-backend_latest.tar.gz ps@10.1.16.50:/home/ps/docker-images/
```

### 3. Load Image trên Server

```bash
# Load image với version cụ thể
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v1.0.0.tar.gz

# Hoặc load latest
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_latest.tar.gz
```

### 4. Deploy với Version cụ thể

```bash
# Deploy với version cụ thể
DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh

# Hoặc dùng latest (default)
./scripts/deploy-production.sh
```

## Cấu trúc thư mục trên Server

**Recommended:**
```
/home/ps/docker-images/
├── aw-visitor-backend_v1.0.0.tar.gz
├── aw-visitor-backend_v1.0.1.tar.gz
├── aw-visitor-backend_v1.1.0.tar.gz
└── aw-visitor-backend_latest.tar.gz
```

**Hoặc theo app:**
```
/home/ps/docker-images/
├── aw-visitor/
│   ├── aw-visitor-backend_v1.0.0.tar.gz
│   └── aw-visitor-backend_latest.tar.gz
├── app2/
│   ├── app2-backend_v1.0.0.tar.gz
│   └── app2-backend_latest.tar.gz
└── ...
```

## Versioning Strategy

### Semantic Versioning (Recommended)

```
v1.0.0  - Major.Minor.Patch
v1.0.1  - Bug fix
v1.1.0  - New feature
v2.0.0  - Breaking changes
```

### Date-based Versioning

```
20241230  - YYYYMMDD
20241230-1  - Date + build number
```

### Git-based Versioning

```
v1.0.0-gabc1234  - Version + git commit hash
```

## Workflow đầy đủ với Version

### Lần đầu setup

**Trên máy dev:**
```bash
# 1. Build và save với version
./scripts/build-and-save-image.sh v1.0.0

# 2. Copy lên server
scp docker-images/aw-visitor-backend_v1.0.0.tar.gz ps@10.1.16.50:/home/ps/docker-images/
```

**Trên server:**
```bash
# 3. Load image
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v1.0.0.tar.gz

# 4. Deploy code
./scripts/deploy-production.sh
```

### Update dependencies (cần rebuild image)

**Trên máy dev:**
```bash
# 1. Build version mới
./scripts/build-and-save-image.sh v1.0.1

# 2. Copy lên server
scp docker-images/aw-visitor-backend_v1.0.1.tar.gz ps@10.1.16.50:/home/ps/docker-images/
```

**Trên server:**
```bash
# 3. Load version mới
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v1.0.1.tar.gz

# 4. Deploy với version mới
DOCKER_IMAGE_VERSION=v1.0.1 ./scripts/deploy-production.sh
```

### Update code (không cần rebuild image)

**Trên máy dev:**
```bash
# Build code
./scripts/build-backend.sh

# Copy build folder
scp -r aw-visitor-backend-adonisjs/build ps@10.1.16.50:/path/to/aw-visitor-docker/aw-visitor-backend-adonisjs/
```

**Trên server:**
```bash
# Deploy (dùng image version hiện tại)
./scripts/deploy-production.sh
```

## Rollback

Nếu có vấn đề với version mới:

```bash
# Load version cũ
./scripts/load-image.sh /home/ps/docker-images/aw-visitor-backend_v1.0.0.tar.gz

# Deploy với version cũ
DOCKER_IMAGE_VERSION=v1.0.0 ./scripts/deploy-production.sh
```

## Best Practices

### 1. Luôn tag với version cụ thể
```bash
# ✅ Good
./scripts/build-and-save-image.sh v1.0.0

# ❌ Bad (chỉ dùng latest)
./scripts/build-and-save-image.sh
```

### 2. Giữ lại các version cũ
```bash
# Giữ ít nhất 3-5 versions gần nhất để rollback
/home/ps/docker-images/
├── aw-visitor-backend_v1.0.0.tar.gz
├── aw-visitor-backend_v1.0.1.tar.gz
├── aw-visitor-backend_v1.0.2.tar.gz
└── aw-visitor-backend_latest.tar.gz
```

### 3. Document version changes
```bash
# Tạo file changelog
echo "v1.0.1 - Updated dependencies" >> CHANGELOG.md
```

### 4. Verify image sau khi load
```bash
# Check image đã load
docker images | grep aw-visitor-backend

# Verify version
docker inspect aw-visitor-backend:v1.0.0
```

## Tóm tắt

✅ **:latest** - Chỉ là tag mặc định, không có ý nghĩa đặc biệt
✅ **Versioning** - Luôn tag với version cụ thể (v1.0.0, v1.0.1, ...)
✅ **Workflow** - Build với version → Save → Copy → Load → Deploy với version
✅ **Rollback** - Dễ dàng với nhiều versions

**Khi deploy:**
- Chỉ cần set `DOCKER_IMAGE_VERSION=v1.0.0`
- Script tự động tìm và dùng image đúng version
- Fallback về `latest` nếu version không tìm thấy

