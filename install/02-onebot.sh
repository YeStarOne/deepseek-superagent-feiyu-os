#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 02 · OneBot 客户端 + 反向 WS
#
#   sudo bash install/02-onebot.sh --dry-run
#   sudo bash install/02-onebot.sh --yes
#   bash install/02-onebot.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [02]
# 验收（docs/04-deploy.md 路线 B 表 02 行）：反向 WS 端口可连；日志有连接建立
#
# ⚠️ 本脚本**不绑定任何具体客户端实现**（NapCat / Lagrange / 其他都行）：
#   方式 A：给 ONEBOT_IMAGE（docker 镜像）→ 起容器，重启策略 unless-stopped；
#   方式 B：给 ONEBOT_CLIENT_BIN（本机可执行文件路径）→ 生成 systemd 单元接管；
#   两者都不给 → 明确报错并停（不猜测、不自动下载未固定版本的东西）。
#
# 用到的 env：ONEBOT_WS ONEBOT_IMAGE ONEBOT_CONTAINER ONEBOT_CLIENT_BIN
#             ONEBOT_HOME ONEBOT_ACCESS_TOKEN SERVICE_USER TZ
# ⚠️ 扫码登录永远是人工动作（runbook 里写清楚），脚本只保证进程与端口。
# ---------------------------------------------------------------------------
set -euo pipefail
NN=02
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

ONEBOT_WS="${ONEBOT_WS:-ws://127.0.0.1:6098}"
OB_HOST="${ONEBOT_WS#*://}"; OB_HOST="${OB_HOST%%:*}"
OB_PORT="${ONEBOT_WS##*:}"; OB_PORT="${OB_PORT%%/*}"
ONEBOT_CONTAINER="${ONEBOT_CONTAINER:-onebot}"
SERVICE_USER="${SERVICE_USER:-feiyu}"
UNIT=/etc/systemd/system/onebot.service

ws_open() {
  # 纯 bash 探端口，不依赖 nc
  timeout 3 bash -c "</dev/tcp/${OB_HOST}/${OB_PORT}" 2>/dev/null
}

verify() {
  local fail=0
  if ws_open; then log "verify ok: 反向 WS $OB_HOST:$OB_PORT 可连"
  else log "verify FAIL: $OB_HOST:$OB_PORT 连不上（进程没起 / 端口不对）"; fail=1; fi

  if [ -n "${ONEBOT_IMAGE:-}" ] && command -v docker >/dev/null 2>&1; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$ONEBOT_CONTAINER"; then
      log "verify ok: 容器 $ONEBOT_CONTAINER 在运行"
      log "verify: 最近日志"
      docker logs --tail 15 "$ONEBOT_CONTAINER" 2>&1 | sed 's/^/  | /' >&2 || true
    else
      log "verify FAIL: 容器 $ONEBOT_CONTAINER 不在运行"; fail=1
    fi
  elif [ -f "$UNIT" ]; then
    if systemctl is-active --quiet onebot; then log "verify ok: onebot.service active"
    else log "verify FAIL: onebot.service 未 active"; fail=1; fi
    log "verify: 最近日志"
    journalctl -u onebot -n 15 --no-pager 2>/dev/null | sed 's/^/  | /' >&2 || true
  else
    log "verify FAIL: 既没有容器也没有 systemd 单元"; fail=1
  fi

  # 连接建立证据（dsh 侧日志里应有 onebot 反向连接记录）
  if journalctl --user -u dsh-web -n 200 --no-pager 2>/dev/null | grep -qi 'onebot.*connect\|onebot.*ready'; then
    log "verify ok: dsh-web 侧日志有 onebot 连接记录"
  else
    log "verify INFO: dsh-web 侧暂未见 onebot 连接记录（可能是先装 02 后装 03，正常）"
  fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  fatal "需要 root：sudo bash install/$NN-onebot.sh $*"
fi

# --- 02.1 选定方式 ---------------------------------------------------------
if [ -n "${ONEBOT_IMAGE:-}" ]; then
  command -v docker >/dev/null 2>&1 || fatal "给了 ONEBOT_IMAGE 但没有 docker"
  if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$ONEBOT_CONTAINER"; then
    log "SKIP: 容器 $ONEBOT_CONTAINER 已存在（改配置请 docker rm -f 后重跑本步）"
    run docker start "$ONEBOT_CONTAINER"
  else
    log "起容器 $ONEBOT_CONTAINER ← $ONEBOT_IMAGE"
    if [ "$DRY" = 1 ]; then
      log "would: docker run -d --name $ONEBOT_CONTAINER -p $OB_HOST:$OB_PORT:$OB_PORT \\"
      log "        -e ONEBOT_ACCESS_TOKEN=*** --restart unless-stopped $ONEBOT_IMAGE"
    else
      docker run -d --name "$ONEBOT_CONTAINER" \
        -p "$OB_HOST:$OB_PORT:$OB_PORT" \
        --restart unless-stopped \
        --env-file "$ENV_FILE" \
        "$ONEBOT_IMAGE" >/dev/null
    fi
  fi

elif [ -n "${ONEBOT_CLIENT_BIN:-}" ]; then
  if [ -f "$UNIT" ]; then
    log "SKIP: $UNIT 已存在"
  else
    log "生成 $UNIT ← $ONEBOT_CLIENT_BIN"
    if [ "$DRY" = 1 ]; then
      log "would: 写入 $UNIT 并 systemctl enable --now onebot"
    else
      [ -x "$ONEBOT_CLIENT_BIN" ] || fatal "$ONEBOT_CLIENT_BIN 不可执行"
      cat > "$UNIT" <<EOF
[Unit]
Description=OneBot client (reverse WS ${OB_HOST}:${OB_PORT})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${ONEBOT_HOME:-/opt/onebot}
EnvironmentFile=${ENV_FILE}
ExecStart=${ONEBOT_CLIENT_BIN}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
      systemctl daemon-reload
      systemctl enable --now onebot
    fi
  fi

else
  if [ "$DRY" = 1 ]; then
    log "would: 需要 env 给 ONEBOT_IMAGE（docker）或 ONEBOT_CLIENT_BIN（本机可执行文件）"
  else
    fatal "没指定客户端：env 里给 ONEBOT_IMAGE（docker）或 ONEBOT_CLIENT_BIN（本机可执行文件）"
  fi
fi

# --- 02.2 人工动作提醒 -----------------------------------------------------
log "人工步骤（脚本不做）：在客户端里扫码登录，并把反向 WS 指向 ${ONEBOT_WS}"
log "掉登录恢复步骤见 feiyu/docs/05-runbook.md"

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
verify || log "提示：端口不通先看客户端日志；登录态问题不是脚本能修的"
