# GitHub Self-Hosted Runners with Docker

🚀 高效能的 GitHub 自建 Runner 解決方案，支援 Rust、Python、Node.js 開發環境，具備智慧快取系統。

## ✨ 特色

- 🔧 **預裝完整工具鏈**: Rust、Python、Node.js、資料庫客戶端
- 💾 **智慧快取系統**: 大幅減少建置時間
- 🏗️ **多階段建置**: 優化映像大小
- 🔒 **安全隔離**: Docker 容器化部署
- ⚡ **高效能**: 資源最佳化配置
- 🛠️ **易於管理**: 完整的管理腳本

## 🛠️ 預裝工具

### 系統工具
- `curl`, `wget`, `git`, `jq`, `netcat`, `tree`, `vim`
- `postgresql-client`, `mysql-client`, `redis-tools`, `sqlite3`
- `build-essential`, `pkg-config`, `libssl-dev`

### Rust 環境
- Rust 最新穩定版 + Cargo
- `sqlx-cli`, `diesel_cli`, `cargo-watch`, `cargo-edit`, `cargo-audit`

### Node.js 環境
- Node.js 18.x + npm, yarn, pnpm
- TypeScript, ESLint, Prettier
- React/Vue/Angular CLI

### Python 環境
- Python 3 + pip
- `pytest`, `black`, `flake8`, `sqlalchemy`, `psycopg2-binary`, `redis`, `celery`

### 其他工具
- Docker Compose
- 預熱的編譯快取

## 🚀 快速開始

### 1. 克隆專案
```bash
git clone <your-repo>
cd github-runners
```

### 2. 設定環境變數
```bash
cp .env.example .env
# 編輯 .env 檔案，填入你的 GitHub Access Token
nano .env
```

### 3. 建置 Runner 映像
```bash
chmod +x build-runners.sh manage-cache.sh
./build-runners.sh
```

### 4. 啟動 Runners
```bash
docker-compose up -d
```

### 5. 檢查狀態
```bash
docker-compose ps
docker-compose logs -f rust-runner
```

## 📝 設定說明

### 環境變數 (.env)

```bash
# 必填: GitHub Access Token
ACCESS_TOKEN=ghp_your_github_token_here

# 可選: 性能調優
RUST_CARGO_INCREMENTAL=1
NODE_OPTIONS=--max-old-space-size=2048
```

### GitHub Access Token 獲取

1. 前往 GitHub Settings → Developer settings → Personal access tokens
2. 選擇 **Fine-grained tokens** 或 **Tokens (classic)**
3. 設定權限:
   - `repo` (完整儲存庫存取)
   - `workflow` (更新 workflows)
   - `admin:org` (組織層級 runner)

## 🏗️ 架構說明

### Docker Compose 結構
```
├── rust-runner          # Rust/Cargo 專用 runner
├── python-react-runner  # Python/Node.js 專用 runner
└── 快取卷
    ├── rust_cargo_registry    # Rust 依賴快取
    ├── nodejs_npm_cache       # npm 快取
    └── python_pip_cache       # pip 快取
```

### 多階段建置
```dockerfile
# Stage 1: Builder - 編譯工具和依賴
FROM myoung34/github-runner:latest as builder
# 安裝和編譯所有工具...

# Stage 2: Final - 最終執行映像
FROM myoung34/github-runner:latest as final
# 只複製必要的執行檔案
```

## 🎯 在 Workflow 中使用

### Rust 專案範例
```yaml
name: Rust CI
on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, rust, cargo, backend]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Run tests
        run: |
          cargo test
          cargo clippy -- -D warnings
```

### Python/React 專案範例
```yaml
name: Python React CI
on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, python, react, web]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          npm install
          
      - name: Run tests
        run: |
          pytest
          npm test
```

## 🔧 管理命令

### 基本操作
```bash
# 啟動所有 runners
docker-compose up -d

# 查看狀態
docker-compose ps

# 查看日誌
docker-compose logs -f rust-runner

# 重啟 runner
docker-compose restart rust-runner

# 停止所有服務
docker-compose down
```

### 快取管理
```bash
# 查看快取狀態
./manage-cache.sh status

# 清理快取 (保留 runner 註冊)
./manage-cache.sh clean

# 完全重置 (包含 runner 註冊)
./manage-cache.sh reset

# 最佳化快取
./manage-cache.sh optimize

# 備份快取
./manage-cache.sh backup

# 恢復快取
./manage-cache.sh restore
```

## 📊 性能最佳化

### 快取效果
- **Rust**: 首次建置後，後續建置提升 60-80% 速度
- **Node.js**: npm install 提升 70-90% 速度  
- **Python**: pip install 提升 50-70% 速度

### 資源配置
```yaml
# docker-compose.yml 中的資源限制
deploy:
  resources:
    limits:
      memory: 4G      # 記憶體限制
      cpus: '2.0'     # CPU 限制
    reservations:
      memory: 2G      # 記憶體保留
      cpus: '1.0'     # CPU 保留
```

## 🐛 常見問題

### Q: Runner 無法連接到 GitHub
**A**: 檢查 ACCESS_TOKEN 是否正確，確保有適當權限

### Q: 建置時記憶體不足
**A**: 增加 Docker 記憶體限制或調整 shm_size

### Q: pg_isready 命令找不到
**A**: 已在映像中預裝 postgresql-client，確保使用最新映像

### Q: 快取佔用太多空間
**A**: 執行 `./manage-cache.sh optimize` 清理舊快取

### Q: Runner 註冊失敗
**A**: 
1. 檢查 REPO_URL 格式是否正確
2. 確認 ACCESS_TOKEN 有 admin 權限
3. 檢查網路連接

## 🔒 安全考量

1. **ACCESS_TOKEN 保護**: 不要提交到 git，使用 .env 檔案
2. **定期更新**: 定期輪換 access token
3. **最小權限**: 只給予必要的權限
4. **網路隔離**: 考慮使用防火牆限制 runner 網路存取

## 📈 監控和日誌

### 查看 Runner 狀態
```bash
# GitHub 上查看
# Settings → Actions → Runners

# 本地查看
docker-compose ps
./manage-cache.sh status
```

### 日誌管理
```bash
# 查看即時日誌
docker-compose logs -f

# 查看特定 runner 日誌
docker-compose logs rust-runner

# 日誌輪替 (生產環境建議)
docker-compose logs --tail=1000 > runner.log
```

## 🚀 進階配置

### 組織層級 Runner
```yaml
# docker-compose.yml
environment:
  - REPO_URL=https://github.com/YOUR_ORG  # 不包含具體儲存庫
```

### 自訂標籤
```yaml
environment:
  - RUNNER_LABELS=rust,gpu,high-memory,production
```

### 多個相同 Runner
```bash
docker-compose up -d --scale rust-runner=3
```

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

## 📄 授權

MIT License

## 📞 支援

如有問題，請開 Issue 或聯繫維護者。

---

⚡ **提示**: 首次建置可能需要 10-15 分鐘，但後續啟動只需 30 秒！