#!/bin/bash

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Building optimized GitHub Runner image...${NC}"

# 檢查 Docker 建置快取
echo -e "${YELLOW}📦 Checking Docker buildx...${NC}"
if ! docker buildx version >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker buildx not found, using regular build${NC}"
    USE_BUILDX=false
else
    echo -e "${GREEN}✅ Docker buildx available${NC}"
    USE_BUILDX=true
fi

# 建置映像選項
DOCKER_BUILDKIT=1

if [ "$USE_BUILDX" = true ]; then
    echo -e "${BLUE}Building with buildx (advanced caching)...${NC}"
    
    # 使用 buildx 進行多階段建置，啟用快取
    docker buildx build \
        --file Dockerfile.runner \
        --target final \
        --tag github-runner-tools:latest \
        --cache-from type=local,src=/tmp/.buildx-cache \
        --cache-to type=local,dest=/tmp/.buildx-cache-new,mode=max \
        --load \
        .
    
    # 更新快取
    if [ -d /tmp/.buildx-cache-new ]; then
        rm -rf /tmp/.buildx-cache
        mv /tmp/.buildx-cache-new /tmp/.buildx-cache
    fi
else
    echo -e "${BLUE}Building with standard Docker build...${NC}"
    
    # 標準建置
    DOCKER_BUILDKIT=1 docker build \
        -f Dockerfile.runner \
        --target final \
        --tag github-runner-tools:latest \
        .
fi

echo -e "${GREEN}✅ Custom runner image built successfully!${NC}"

# 檢查映像大小
echo -e "${BLUE}📦 Image information:${NC}"
docker images github-runner-tools:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# 映像層分析
echo -e "${BLUE}📊 Image layers:${NC}"
docker history github-runner-tools:latest --format "table {{.CreatedBy}}\t{{.Size}}"

# 測試映像
echo -e "${YELLOW}🧪 Testing image...${NC}"
if docker run --rm github-runner-tools:latest /bin/bash -c "
    echo 'Testing tools...' &&
    which git && echo '✅ Git available' &&
    which node && echo '✅ Node.js available' &&
    which python3 && echo '✅ Python available' &&
    which cargo && echo '✅ Cargo available' &&
    which pg_isready && echo '✅ PostgreSQL client available' &&
    which redis-cli && echo '✅ Redis client available' &&
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
    
    # 標記映像
    docker tag github-runner-tools:latest $DOCKER_USERNAME/github-runner-tools:latest
    
    # 推送映像
    echo -e "${BLUE}📤 Pushing to Docker Hub...${NC}"
    if docker push $DOCKER_USERNAME/github-runner-tools:latest; then
        echo -e "${GREEN}✅ Image pushed to Docker Hub!${NC}"
        echo -e "${YELLOW}💡 You can now use 'image: $DOCKER_USERNAME/github-runner-tools:latest' in your docker-compose.yml${NC}"
        
        # 創建 .env 範例
        cat > .env.example << EOF
# GitHub Access Token
ACCESS_TOKEN=ghp_your_token_here

# Optional: Use pre-built image instead of building locally
# Uncomment the lines below in docker-compose.yml:
# image: $DOCKER_USERNAME/github-runner-tools:latest
# Comment out the 'build:' section
EOF
        echo -e "${GREEN}📝 Created .env.example with Docker Hub image reference${NC}"
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
echo -e "${BLUE}💾 Cache volumes created:${NC}"
echo "- Rust cargo cache: rust_cargo_registry, rust_cargo_git"
echo "- Node.js cache: nodejs_npm_cache, nodejs_yarn_cache" 
echo "- Python cache: python_pip_cache, python_venv_cache"
echo
echo -e "${YELLOW}🔧 Cache management commands:${NC}"
echo "- Clean all caches: docker-compose down -v"
echo "- Clean only build caches: docker volume prune"
echo "- View cache usage: docker system df"