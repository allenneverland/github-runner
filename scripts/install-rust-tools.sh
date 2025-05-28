#!/bin/bash
set -e

echo "🦀 Installing Rust and tools..."

# 檢查是否已安裝 Rust
if ! command -v cargo &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
else
    echo "Rust already installed"
fi

# 安裝 Rust 工具
echo "Installing Rust tools..."
cargo install sqlx-cli --no-default-features --features postgres,sqlite || echo "sqlx-cli install failed, continuing..."
cargo install cargo-watch || echo "cargo-watch install failed, continuing..."

echo "✅ Rust tools installation completed"