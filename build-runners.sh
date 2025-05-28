#!/bin/bash

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Building GitHub Runner image (simplified)...${NC}"

# 使用標準 Docker 建置
echo -e "${BLUE}Building with standard Docker build...${NC}"

# 建置映像
DOCKER_BUILDKIT=1 docker build \
    -f Dockerfile.runner \
    --target final \
    --tag github-runner-tools:latest \
    .

echo -e "${GREEN}✅ Custom runner image built successfully!${NC}"

# 檢查映像大小
echo -e "${BLUE}📦 Image information:${NC}"
docker images github-runner-tools:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# 映像層分析
echo -e "${BLUE}📊 Image layers (top 10):${NC}"
docker history github-runner-tools:latest --format "table {{.CreatedBy}}\t{{.Size}}" | head -11

# 測試映像
echo -e "${YELLOW}🧪 Testing image...${NC}"
if docker run --rm --entrypoint="" github-runner-tools:latest /bin/bash -c "
    echo 'Testing tools...' &&
    which git >/dev/null && echo '✅ Git available' &&
    which node >/dev/null && echo '✅ Node.js available' &&
    which python3 >/dev/null && echo '✅ Python available' &&
    which cargo >/dev/null && echo '✅ Cargo available' &&
    which pg_isready >/dev/null && echo '✅ PostgreSQL client available' &&
    which redis-cli >/dev/null && echo '✅ Redis client available' &&
    echo 'All tools working!'
"; then
    echo -e "${GREEN}✅ Image test passed!${NC}"
else
    echo -e "${RED}❌ Image test failed!${NC}"
    exit 1
fi

# 快取管理
echo -e "${BLUE}🧹 Cleaning up old images...${NC}"
docker image prune -f

# 可選：推送到 Docker Hub
echo
read -p "🤔 Do you want to push to Docker Hub? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter your Docker Hub username: " DOCKER_USERNAME
    
    if [ -z "$DOCKER_USERNAME" ]; then
        echo -e "${RED}❌ Username cannot be empty${NC}"
        exit 1
    fi
    
    # 檢查是否已登入 Docker Hub
    if ! docker info | grep -q "Username:"; then
        echo -e "${YELLOW}⚠️  Please login to Docker Hub first:${NC}"
        echo "docker login"
        exit 1
    fi
    
    # 標記映像
    echo -e "${BLUE}🏷️  Tagging image...${NC}"
    docker tag github-runner-tools:latest $DOCKER_USERNAME/github-runner-tools:latest
    
    # 推送映像
    echo -e "${BLUE}📤 Pushing to Docker Hub...${NC}"
    if docker push $DOCKER_USERNAME/github-runner-tools:latest; then
        echo -e "${GREEN}✅ Image pushed to Docker Hub!${NC}"
        echo -e "${YELLOW}💡 You can now use this in docker-compose.yml:${NC}"
        echo "    image: $DOCKER_USERNAME/github-runner-tools:latest"
        
        # 更新 docker-compose.yml 範例
        if [ -f "docker-compose.yml" ]; then
            cp docker-compose.yml docker-compose.yml.backup
            echo -e "${BLUE}📝 Created backup: docker-compose.yml.backup${NC}"
        fi
        
        # 創建使用預建映像的版本
        cat > docker-compose.prebuilt.yml << EOF
version: '3.8'

services:
  # Rust Runner
  rust-runner:
    image: $DOCKER_USERNAME/github-runner-tools:latest
    container_name: rust-runner
    restart: unless-stopped
    environment:
      - REPO_URL=https://github.com/allenneverland/backtest-server
      - ACCESS_TOKEN=\${ACCESS_TOKEN}
      - RUNNER_NAME=rust-runner
      - RUNNER_LABELS=rust,cargo,backend,linux,x64
      - RUNNER_GROUP=default
      - RUNNER_WORK_DIRECTORY=/tmp/runner/work
      - CARGO_HOME=/home/runner/.cargo
      - CARGO_TARGET_DIR=/tmp/cargo-target
      - CARGO_INCREMENTAL=1
      - CARGO_NET_RETRY=10
      - RUSTUP_MAX_RETRIES=10
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - rust_runner_data:/tmp/runner
      - rust_cargo_registry:/home/runner/.cargo/registry
      - rust_cargo_git:/home/runner/.cargo/git
      - rust_cargo_target:/tmp/cargo-target
      - shared_cargo_cache:/home/runner/.cargo/registry/cache
    shm_size: '2gb'
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
        reservations:
          memory: 2G
          cpus: '1.0'

  # Python & React Runner
  python-react-runner:
    image: $DOCKER_USERNAME/github-runner-tools:latest
    container_name: python-react-runner
    restart: unless-stopped
    environment:
      - REPO_URL=https://github.com/allenneverland/stratplat-web-server
      - ACCESS_TOKEN=\${ACCESS_TOKEN}
      - RUNNER_NAME=python-react-runner
      - RUNNER_LABELS=python,react,nodejs,web,linux,x64
      - RUNNER_GROUP=default
      - RUNNER_WORK_DIRECTORY=/tmp/runner/work
      - NPM_CONFIG_CACHE=/home/runner/.npm
      - YARN_CACHE_FOLDER=/home/runner/.yarn-cache
      - PIP_CACHE_DIR=/home/runner/.cache/pip
      - NODE_OPTIONS=--max-old-space-size=2048
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - python_react_runner_data:/tmp/runner
      - nodejs_npm_cache:/home/runner/.npm
      - nodejs_yarn_cache:/home/runner/.yarn-cache
      - nodejs_node_modules:/tmp/node_modules_cache
      - python_pip_cache:/home/runner/.cache/pip
      - python_venv_cache:/home/runner/.local
    shm_size: '2gb'
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
        reservations:
          memory: 2G
          cpus: '1.0'

volumes:
  rust_runner_data:
    driver: local
  python_react_runner_data:
    driver: local
  rust_cargo_registry:
    driver: local
  rust_cargo_git:
    driver: local
  rust_cargo_target:
    driver: local
  shared_cargo_cache:
    driver: local
  nodejs_npm_cache:
    driver: local
  nodejs_yarn_cache:
    driver: local
  nodejs_node_modules:
    driver: local
  python_pip_cache:
    driver: local
  python_venv_cache:
    driver: local
EOF
        
        echo -e "${GREEN}📝 Created docker-compose.prebuilt.yml${NC}"
        echo -e "${YELLOW}💡 To use prebuilt image: docker-compose -f docker-compose.prebuilt.yml up -d${NC}"
        
    else
        echo -e "${RED}❌ Failed to push image${NC}"
    fi
fi

# 顯示使用說明
echo
echo -e "${GREEN}🎉 Setup completed!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create .env file: cp .env.example .env"
echo "2. Edit .env with your GitHub token"
echo "3. Start runners: docker-compose up -d"
echo "4. Check status: docker-compose ps"
echo "5. View logs: docker-compose logs -f"
echo
echo -e "${BLUE}💾 Available cache volumes:${NC}"
echo "- Rust cargo cache: rust_cargo_registry, rust_cargo_git"
echo "- Node.js cache: nodejs_npm_cache, nodejs_yarn_cache" 
echo "- Python cache: python_pip_cache, python_venv_cache"
echo
echo -e "${YELLOW}🔧 Management commands:${NC}"
echo "- Cache status: ./manage-cache.sh status"
echo "- Clean caches: ./manage-cache.sh clean"
echo "- View system usage: docker system df"