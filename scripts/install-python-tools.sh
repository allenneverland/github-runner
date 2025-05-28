#!/bin/bash
set -e

echo "🐍 Installing Python and Node.js tools..."

# 安裝 Python 套件
echo "Installing Python packages..."
python3 -m pip install --user \
    pytest \
    black \
    flake8 \
    requests \
    sqlalchemy \
    psycopg2-binary \
    redis \
    celery || echo "Some Python packages failed to install, continuing..."

# 安裝 Node.js 全域套件
echo "Installing Node.js packages..."
npm config set prefix '/home/runner/.local'
npm install -g \
    yarn \
    typescript \
    eslint \
    prettier || echo "Some npm packages failed to install, continuing..."

echo "✅ Python and Node.js tools installation completed"