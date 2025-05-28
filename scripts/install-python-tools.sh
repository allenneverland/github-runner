#!/bin/bash
set -e

echo "🐍 Installing Python and Node.js tools..."

# 確保以 runner 用戶身份運行 Python 安裝
echo "Installing Python packages as runner user..."
python3 -m pip install --user --no-warn-script-location \
    pytest \
    black \
    flake8 \
    requests \
    sqlalchemy \
    psycopg2-binary \
    redis \
    celery || echo "Some Python packages failed to install, continuing..."

# 安裝較新的 Node.js
echo "Installing newer Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 等待 Node.js 安裝完成
sleep 2

# 檢查 Node.js 版本
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# 安裝 Node.js 全域套件 (使用相容版本)
echo "Installing Node.js packages..."
npm config set prefix '/home/runner/.local'

# 安裝相容版本的套件
npm install -g \
    yarn@1.22.19 \
    typescript@4.9.5 \
    eslint@8.42.0 \
    prettier@2.8.8 || echo "Some npm packages failed to install, continuing..."

# 確保 PATH 包含本地安裝的工具
echo 'export PATH="/home/runner/.local/bin:$PATH"' >> ~/.bashrc

echo "✅ Python and Node.js tools installation completed"