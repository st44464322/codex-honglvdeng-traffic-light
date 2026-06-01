#!/bin/zsh
set -e

cd "$(dirname "$0")"
TARGET_DIR="$HOME/.codex/bin"

mkdir -p "$TARGET_DIR"
ln -sf "$PWD/codex-light" "$TARGET_DIR/codex-light"
ln -sf "$PWD/codex-light-run" "$TARGET_DIR/codex-light-run"
ln -sf "$PWD/codex-light-hook" "$TARGET_DIR/codex-light-hook"
ln -sf "$PWD/codex-light-notify" "$TARGET_DIR/codex-light-notify"

echo "已接入："
echo "$TARGET_DIR/codex-light"
echo "$TARGET_DIR/codex-light-run"
echo "$TARGET_DIR/codex-light-hook"
echo "$TARGET_DIR/codex-light-notify"
echo ""
echo "如果命令找不到，把这行加入 ~/.zshrc："
echo "export PATH=\"\$HOME/.codex/bin:\$PATH\""
