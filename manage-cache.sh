#!/bin/bash

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo -e "${BLUE}🔧 GitHub Runner Cache Management${NC}"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  status    - Show cache volume usage"
    echo "  clean     - Clean all caches (keeps data volumes)"
    echo "  reset     - Reset everything (including runner data)"
    echo "  backup    - Backup cache volumes"
    echo "  restore   - Restore cache volumes"
    echo "  optimize  - Optimize cache volumes"
    echo
}

show_status() {
    echo -e "${BLUE}📊 Cache Volume Status${NC}"
    echo
    
    echo -e "${YELLOW}Docker System Usage:${NC}"
    docker system df
    echo
    
    echo -e "${YELLOW}Volume Details:${NC}"
    docker volume ls --filter name=rust_ --filter name=nodejs_ --filter name=python_ --filter name=shared_
    echo
    
    echo -e "${YELLOW}Runner Status:${NC}"
    docker-compose ps
}

clean_caches() {
    echo -e "${YELLOW}🧹 Cleaning cache volumes...${NC}"
    
    # 停止 runners
    docker-compose stop
    
    # 清理快取卷 (保留 runner 資料)
    echo -e "${BLUE}Removing cache volumes...${NC}"
    docker volume rm -f \
        rust_cargo_registry \
        rust_cargo_git \
        rust_cargo_target \
        shared_cargo_cache \
        nodejs_npm_cache \
        nodejs_yarn_cache \
        nodejs_node_modules \
        python_pip_cache \
        python_venv_cache 2>/dev/null || true
    
    # 清理未使用的映像
    docker image prune -f
    
    # 重新啟動
    docker-compose up -d
    
    echo -e "${GREEN}✅ Cache cleaned and runners restarted${NC}"
}

reset_all() {
    read -p "⚠️  This will remove ALL data including runner registrations. Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}🗑️  Removing all volumes and containers...${NC}"
        
        docker-compose down -v
        docker system prune -f
        
        echo -e "${GREEN}✅ Complete reset finished${NC}"
        echo -e "${YELLOW}💡 Run 'docker-compose up -d' to recreate runners${NC}"
    else
        echo -e "${BLUE}Operation cancelled${NC}"
    fi
}

backup_caches() {
    BACKUP_DIR="./cache-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    echo -e "${BLUE}💾 Backing up cache volumes to $BACKUP_DIR${NC}"
    
    # 備份每個快取卷
    for volume in rust_cargo_registry rust_cargo_git nodejs_npm_cache nodejs_yarn_cache python_pip_cache; do
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            echo -e "${YELLOW}Backing up $volume...${NC}"
            docker run --rm \
                -v "$volume":/source \
                -v "$(pwd)/$BACKUP_DIR":/backup \
                alpine tar czf "/backup/$volume.tar.gz" -C /source .
        fi
    done
    
    echo -e "${GREEN}✅ Backup completed in $BACKUP_DIR${NC}"
}

restore_caches() {
    read -p "Enter backup directory path: " BACKUP_DIR
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}❌ Backup directory not found${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📥 Restoring cache volumes from $BACKUP_DIR${NC}"
    
    # 停止 runners
    docker-compose stop
    
    # 恢復每個快取卷
    for backup_file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$backup_file" ]; then
            volume_name=$(basename "$backup_file" .tar.gz)
            echo -e "${YELLOW}Restoring $volume_name...${NC}"
            
            # 創建卷 (如果不存在)
            docker volume create "$volume_name"
            
            # 恢復資料
            docker run --rm \
                -v "$volume_name":/target \
                -v "$BACKUP_DIR":/backup \
                alpine tar xzf "/backup/$volume_name.tar.gz" -C /target
        fi
    done
    
    # 重新啟動
    docker-compose up -d
    
    echo -e "${GREEN}✅ Cache restoration completed${NC}"
}

optimize_caches() {
    echo -e "${BLUE}⚡ Optimizing cache volumes...${NC}"
    
    # 清理 Cargo 快取
    if docker volume inspect rust_cargo_registry >/dev/null 2>&1; then
        echo -e "${YELLOW}Optimizing Rust cargo cache...${NC}"
        docker run --rm \
            -v rust_cargo_registry:/cargo \
            rust:latest \
            /bin/bash -c "
                cd /cargo && \
                find . -name '*.rlib' -mtime +30 -delete && \
                find . -name '*.rmeta' -mtime +30 -delete && \
                find . -type d -empty -delete
            "
    fi
    
    # 清理 npm 快取
    if docker volume inspect nodejs_npm_cache >/dev/null 2>&1; then
        echo -e "${YELLOW}Optimizing npm cache...${NC}"
        docker run --rm \
            -v nodejs_npm_cache:/npm \
            node:18-alpine \
            /bin/sh -c "
                cd /npm && \
                find . -type f -mtime +30 -delete && \
                find . -type d -empty -delete
            "
    fi
    
    # 清理 pip 快取
    if docker volume inspect python_pip_cache >/dev/null 2>&1; then
        echo -e "${YELLOW}Optimizing pip cache...${NC}"
        docker run --rm \
            -v python_pip_cache:/pip \
            python:3.11-alpine \
            /bin/sh -c "
                cd /pip && \
                find . -name '*.whl' -mtime +30 -delete && \
                find . -type d -empty -delete
            "
    fi
    
    echo -e "${GREEN}✅ Cache optimization completed${NC}"
}

# 主要邏輯
case "${1:-}" in
    status)
        show_status
        ;;
    clean)
        clean_caches
        ;;
    reset)
        reset_all
        ;;
    backup)
        backup_caches
        ;;
    restore)
        restore_caches
        ;;
    optimize)
        optimize_caches
        ;;
    *)
        show_usage
        exit 1
        ;;
esac