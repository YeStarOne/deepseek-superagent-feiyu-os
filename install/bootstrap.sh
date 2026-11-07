#!/usr/bin/env bash
# 一键体验：clone 仓库 → 预演本地种子 → 指引启动
# 用法: bash bootstrap.sh [目标目录]     （默认目录 deepseek-superagent-feiyu-os）
set -euo pipefail

REPO="https://github.com/YeStarOne/deepseek-superagent-feiyu-os.git"
DIR="${1:-deepseek-superagent-feiyu-os}"

echo "[bootstrap] 1/3 clone 仓库 → $DIR"
[ -d "$DIR/.git" ] && echo "  目录已存在，跳过 clone" || git clone --depth 1 "$REPO" "$DIR"
cd "$DIR"

echo "[bootstrap] 2/3 预演本地种子（--dry-run，不改系统）"
bash install/local/seed.sh --dry-run

echo "[bootstrap] 3/3 下一步"
cat <<'EOF'

  确认预演输出没问题后，两步起鱼：

    bash install/local/seed.sh --yes     # 平台 + 记忆目录 + 起停/体检脚本
    ~/.feiyu/bin/start.sh                # 起，浏览器开 http://127.0.0.1:3080

  .env 至少填 API_KEY / API_BASE / MODEL_MAIN 三项（见 env.example）。
  出问题先跑 ~/.feiyu/bin/doctor.sh；细节见 feiyu/docs/00-getting-started.md。
EOF
