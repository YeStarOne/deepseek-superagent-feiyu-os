#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 10 · 团队网（信箱桥 + relay + 心跳）
#
#   sudo bash install/10-team.sh --dry-run
#   sudo bash install/10-team.sh --yes
#   bash install/10-team.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [10]
# 验收（docs/04-deploy.md 路线 B 表 10 行）：两会话互通且互相叫醒
#
# 依赖 08（superagent）+ 09（看护）。
# ⚠️ 单人使用可跳过本步：脑 + 记忆 + 工单不依赖团队网。
#
# 用到的 env：WORKSPACE PYTHON_BIN SERVICE_USER RN_RELAY RN_SESSION
#             RN_BRIDGE_REPO RN_BRIDGE_HOME RN_WAKE RN_WAKE_MODEL
#             RN_WAKE_MODEL_FALLBACK SHIFT_INTERVAL_MIN ENV_FILE
# ---------------------------------------------------------------------------
set -euo pipefail
NN=10
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
    *) log "未知参数：$a"; exit 2 ;;
  esac
done
run() { if [ "$DRY" = 1 ]; then log "would: $*"; else "$@"; fi; }

WORKSPACE="${WORKSPACE:-$HOME/work}"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || echo python3)}"
SERVICE_USER="${SERVICE_USER:-feiyu}"
RN_SESSION="${RN_SESSION:-host}"
RN_BRIDGE_HOME="${RN_BRIDGE_HOME:-$WORKSPACE/rn-mailbox-bridge}"
RN_HEARTBEAT_MIN="${SHIFT_INTERVAL_MIN:-20}"
UNIT=/etc/systemd/system/rn-mailbox-bridge.service
MARK='# feiyu-install:10'

verify() {
  local fail=0
  if [ -z "${RN_RELAY:-}" ]; then
    log "verify FAIL: env 里没有 RN_RELAY"; fail=1
  else
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$RN_RELAY" || true)"
    if [ "$code" != "000" ] && [ -n "$code" ]; then log "verify ok: relay 可达（$code）"
    else log "verify FAIL: relay 不可达 $RN_RELAY"; fail=1; fi
  fi

  if systemctl is-active --quiet rn-mailbox-bridge 2>/dev/null; then
    log "verify ok: rn-mailbox-bridge.service active"
  else
    log "verify FAIL: rn-mailbox-bridge.service 未 active"; fail=1
  fi
  log "verify: 最近日志"
  journalctl -u rn-mailbox-bridge -n 12 --no-pager 2>/dev/null | sed 's/^/  | /' >&2 || true

  if crontab -l 2>/dev/null | grep -qF "$MARK"; then
    log "verify ok: 心跳 cron 已装（每 ${RN_HEARTBEAT_MIN} 分钟）"
    crontab -l 2>/dev/null | grep -A2 -F "$MARK" | sed 's/^/  | /' >&2 || true
  else
    log "verify INFO: 心跳 cron 未装（单人使用可不装）"
  fi

  log "人工验收：两个会话互发一条信，空闲方约 20–30 秒被叫醒（看回家信或唤醒日志）"
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  fatal "需要 root 写 systemd 单元：sudo bash install/$NN-team.sh $*"
fi

if [ -z "${RN_RELAY:-}" ]; then
  if [ "$DRY" = 1 ]; then
    log "would: 需要 env RN_RELAY（例：http://\${HOST_TAILSCALE}:3340/）"
  else
    fatal "env 缺 RN_RELAY（例：http://\${HOST_TAILSCALE}:3340/）"
  fi
fi

# --- 10.1 信箱桥 -----------------------------------------------------------
BRIDGE_REPO="${RN_BRIDGE_REPO:-https://github.com/YeStarOne/rn-mailbox-bridge.git}"
if [ -d "$RN_BRIDGE_HOME/.git" ]; then
  log "更新信箱桥"
  if [ "$DRY" = 1 ]; then log "would: git -C $RN_BRIDGE_HOME pull --ff-only"
  else git -C "$RN_BRIDGE_HOME" pull --ff-only; fi
else
  log "clone 信箱桥 ← $BRIDGE_REPO"
  run git clone --depth 1 "$BRIDGE_REPO" "$RN_BRIDGE_HOME"
fi

# --- 10.2 系统单元 ---------------------------------------------------------
if [ -f "$UNIT" ]; then
  log "SKIP: $UNIT 已存在"
else
  if [ "$DRY" = 1 ]; then
    log "would: 写 $UNIT 并 systemctl enable --now rn-mailbox-bridge"
  else
    cat > "$UNIT" <<EOF
[Unit]
Description=reason-network mailbox bridge (${RN_SESSION})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${RN_BRIDGE_HOME}
EnvironmentFile=${ENV_FILE}
Environment=RN_RELAY=${RN_RELAY}
Environment=RN_SESSION=${RN_SESSION}
Environment=RN_WAKE=${RN_WAKE:-1}
ExecStart=${PYTHON_BIN} ${RN_BRIDGE_HOME}/bridge.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now rn-mailbox-bridge
  fi
fi

# --- 10.3 心跳 cron（不在这里写进总调度的间隔，按 env） --------------------
if crontab -l 2>/dev/null | grep -qF "$MARK"; then
  log "SKIP: 心跳 cron 已装"
else
  if [ "$DRY" = 1 ]; then
    log "would: 每 ${RN_HEARTBEAT_MIN} 分钟跑一次 bridge.py --heartbeat"
  else
    TMP="$(mktemp)"
    {
      crontab -l 2>/dev/null || true
      echo "$MARK"
      echo "*/${RN_HEARTBEAT_MIN} * * * * ${PYTHON_BIN} ${RN_BRIDGE_HOME}/bridge.py --heartbeat >> ${WORKSPACE}/logs/rn-heartbeat.log 2>&1"
    } > "$TMP"
    crontab "$TMP"; rm -f "$TMP"
    log "心跳 cron 已装"
  fi
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
log "唤醒策略：RN_WAKE=1 时空闲会话会被直接叫醒；模型主线 ${RN_WAKE_MODEL:-<未设>}，回退 ${RN_WAKE_MODEL_FALLBACK:-<未设>}"
verify || log "提示：relay 可达但叫不醒，先看桥日志里 followup / wake 的返回"
