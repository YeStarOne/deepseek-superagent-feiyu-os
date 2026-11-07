#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 01 · 基础系统：用户 / swap / 时区 / tailnet
#
#   sudo bash install/01-base.sh --dry-run
#   sudo bash install/01-base.sh --yes
#   bash install/01-base.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [01]
# 验收（docs/04-deploy.md 路线 B 表 01 行）：tailscale status 在线；时区正确
#
# 用到的 env（env.example 键名，值只在 .env，脚本内零真值）：
#   TZ SERVICE_USER SWAP_SIZE TAILSCALE_AUTHKEY TAILSCALE_VERSION
# ---------------------------------------------------------------------------
set -euo pipefail
NN=01
log() { printf '[%s] %s\n' "$NN" "$*" >&2; }
fatal() { log "FATAL: $*"; exit 3; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${INSTALL_ENV:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then set -a; . "$ENV_FILE"; set +a; fi

DRY=0; VERIFY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --verify)  VERIFY=1 ;;
    --yes)     : ;;
    *) log "未知参数：$a（支持 --dry-run / --verify / --yes）"; exit 2 ;;
  esac
done

run() { if [ "$DRY" = 1 ]; then log "would: $*"; else "$@"; fi; }

PYBIN="$(command -v python3 || command -v python || echo python3)"
SERVICE_USER="${SERVICE_USER:-feiyu}"
SWAP_SIZE="${SWAP_SIZE:-2G}"
TZ="${TZ:-Asia/Shanghai}"

verify() {
  local fail=0
  if id "$SERVICE_USER" >/dev/null 2>&1; then
    log "verify ok: 用户 $SERVICE_USER 存在（uid $(id -u "$SERVICE_USER")）"
  else
    log "verify FAIL: 用户 $SERVICE_USER 不存在"; fail=1
  fi

  local tz_now
  tz_now="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  if [ "$tz_now" = "$TZ" ]; then log "verify ok: 时区 $tz_now"
  else log "verify FAIL: 时区是 '${tz_now:-未知}'，期望 $TZ"; fail=1; fi

  if swapon --show=NAME --noheadings 2>/dev/null | grep -q .; then
    log "verify ok: swap 已启用（$(swapon --show=SIZE --noheadings 2>/dev/null | head -1 | tr -d ' ')）"
  else
    log "verify FAIL: 没有启用的 swap（1.7G 小机器必备）"; fail=1
  fi

  if command -v tailscale >/dev/null 2>&1; then
    local ts
    ts="$(tailscale status 2>&1 | head -3 || true)"
    if [ -n "$ts" ] && ! printf '%s' "$ts" | grep -qi 'logged out\|not logged in'; then
      # ⚠️ 红线：不打印 tailnet 主机名/地址，只报后端状态与对端数量
      local state peers
      state="$(tailscale status --json 2>/dev/null | "$PYBIN" -c 'import json,sys;print(json.load(sys.stdin).get("BackendState","?"))' 2>/dev/null || echo unknown)"
      peers="$(tailscale status --json 2>/dev/null | "$PYBIN" -c 'import json,sys;print(len(json.load(sys.stdin).get("Peer") or {}))' 2>/dev/null || echo "?")"
      log "verify ok: tailscale 在线（backend=$state，对端 $peers 个）"
    else
      log "verify FAIL: tailscale 未登录（tailscale up 需要 authkey）"; fail=1
    fi
  else
    log "verify FAIL: tailscale 未安装"; fail=1
  fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  fatal "需要 root：sudo bash install/$NN-base.sh $*"
fi

# --- 01.1 服务用户 ---------------------------------------------------------
if id "$SERVICE_USER" >/dev/null 2>&1; then
  log "SKIP: 用户 $SERVICE_USER 已存在"
else
  log "创建服务用户 $SERVICE_USER"
  run useradd -m -s /bin/bash "$SERVICE_USER"
fi

# --- 01.2 swap -------------------------------------------------------------
if swapon --show=NAME --noheadings 2>/dev/null | grep -q .; then
  log "SKIP: swap 已启用"
else
  log "创建 ${SWAP_SIZE} swapfile"
  if [ "$DRY" = 1 ]; then
    log "would: fallocate -l $SWAP_SIZE /swapfile && mkswap && swapon && 写 /etc/fstab"
  else
    fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    log "swap 已启用并写入 /etc/fstab"
  fi
fi

# --- 01.3 时区 -------------------------------------------------------------
if [ "$(timedatectl show -p Timezone --value 2>/dev/null || true)" = "$TZ" ]; then
  log "SKIP: 时区已经是 $TZ"
else
  log "设置时区 $TZ"
  run timedatectl set-timezone "$TZ"
fi

# --- 01.4 tailnet ----------------------------------------------------------
if command -v tailscale >/dev/null 2>&1; then
  log "SKIP: tailscale 已安装（$(tailscale version 2>/dev/null | head -1)）"
else
  log "安装 tailscale（官方 apt 源，不用 curl|sh）"
  if [ "$DRY" = 1 ]; then
    log "would: 添加 pkgs.tailscale.com 源 + apt-get install tailscale${TAILSCALE_VERSION:+=$TAILSCALE_VERSION}"
  else
    need() { command -v "$1" >/dev/null 2>&1 || fatal "缺少 $1"; }
    need curl; need gpg; need apt-get
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
      -o /etc/apt/sources.list.d/tailscale.list
    apt-get update -qq
    if [ -n "${TAILSCALE_VERSION:-}" ]; then
      apt-get install -y -qq "tailscale=$TAILSCALE_VERSION"
    else
      apt-get install -y -qq tailscale
    fi
  fi
fi

if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
  if tailscale status >/dev/null 2>&1; then
    log "SKIP: tailnet 已登录"
  else
    log "tailscale up（authkey 来自 env，不打印）"
    if [ "$DRY" = 1 ]; then
      log "would: tailscale up --authkey *** --hostname \${HOSTNAME}"
    else
      tailscale up --authkey "$TAILSCALE_AUTHKEY" --hostname "$(hostname -s)"
    fi
  fi
else
  log "WARN: env 里没有 TAILSCALE_AUTHKEY —— 装好客户端后需人工 tailscale up"
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
verify || log "提示：FAIL 项见 docs/04-deploy.md 路线 B 表 01 行"
