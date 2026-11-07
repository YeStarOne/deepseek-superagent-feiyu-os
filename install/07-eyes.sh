#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 07 · 眼睛（eye-server + PC 桥）
#
#   sudo bash install/07-eyes.sh --dry-run
#   sudo bash install/07-eyes.sh --yes
#   bash install/07-eyes.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [07]
# 验收（docs/04-deploy.md 路线 B 表 07 行）：/health 通；一条笔记落盘
#
# 眼睛 = 只读观察 + 节流 + SKIP 判定，产出 notes.jsonl 给下游源消费。
# ⚠️ 硬约束：只读 notes.jsonl（下游只追加不改），眼睛自己不做处置动作。
#
# 用到的 env：WORKSPACE PYTHON_BIN SERVICE_USER EYE_PORT EYE_TOKEN
#             EYE_CLIP_PER_HOUR EYE_NOTES ENV_FILE
# ---------------------------------------------------------------------------
set -euo pipefail
NN=07
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
EYE_PORT="${EYE_PORT:-8901}"
EYE_CLIP_PER_HOUR="${EYE_CLIP_PER_HOUR:-30}"
EYE_NOTES="${EYE_NOTES:-$WORKSPACE/state/notes.jsonl}"
EYE_PY="$WORKSPACE/eye_server.py"
UNIT=/etc/systemd/system/eye-server.service

health() {
  if [ -n "${EYE_TOKEN:-}" ]; then
    curl -sS --max-time 5 -H "Authorization: Bearer $EYE_TOKEN" "http://127.0.0.1:$EYE_PORT/health"
  else
    curl -sS --max-time 5 "http://127.0.0.1:$EYE_PORT/health"
  fi
}

verify() {
  local fail=0
  local body
  if body="$(health 2>&1)"; then
    log "verify ok: /health 通 —— $(printf '%s' "$body" | head -c 200)"
  else
    log "verify FAIL: /health 不通（systemctl status eye-server）"; fail=1
  fi

  if [ -f "$EYE_NOTES" ]; then
    local n; n="$(wc -l < "$EYE_NOTES")"
    log "verify ok: 笔记落盘 $EYE_NOTES（$n 行）"
    log "verify: 最后一条"
    tail -1 "$EYE_NOTES" | sed 's/^/  | /' >&2 || true
  else
    log "verify FAIL: 还没有 $EYE_NOTES（眼睛没写下任何东西）"; fail=1
  fi

  if [ "$EYE_CLIP_PER_HOUR" -ge 1 ] 2>/dev/null && [ "$EYE_CLIP_PER_HOUR" -le 120 ] 2>/dev/null; then
    log "verify ok: 节流 $EYE_CLIP_PER_HOUR 帧/小时"
  else
    log "verify WARN: EYE_CLIP_PER_HOUR=$EYE_CLIP_PER_HOUR 超出合理区间 1..120"
  fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  fatal "需要 root 写 systemd 单元：sudo bash install/$NN-eyes.sh $*"
fi

if [ ! -f "$EYE_PY" ]; then
  if [ "$DRY" = 1 ]; then
    log "would: 需要 $EYE_PY（眼睛服务端脚本不在本仓，实现仓私有）"
  else
    fatal "缺 $EYE_PY —— 眼睛服务端脚本不在本仓（实现仓私有），先把可执行文件放到 $WORKSPACE/"
  fi
fi
run mkdir -p "$(dirname "$EYE_NOTES")" "$WORKSPACE/logs"

if [ -f "$UNIT" ]; then
  log "SKIP: $UNIT 已存在"
else
  SRC="$REPO_DIR/deploy/systemd/eye-server.service.in"
  [ -f "$SRC" ] || fatal "找不到 $SRC"
  if [ "$DRY" = 1 ]; then
    log "would: 渲染 $SRC → $UNIT 并 systemctl enable --now eye-server"
  else
    out="$(cat "$SRC")"; missing=""
    for key in SERVICE_USER WORKSPACE ENV_FILE PYTHON_BIN EYE_PORT EYE_CLIP_PER_HOUR; do
      val="${!key:-}"
      if [ -z "$val" ]; then missing="$missing $key"; else out="${out//@$key@/$val}"; fi
    done
    [ -z "$missing" ] || fatal "模板缺 env：$missing"
    left="$(printf '%s' "$out" | grep -oE '@[A-Z0-9_]+@' | sort -u | tr '\n' ' ' || true)"
    if [ -n "$left" ]; then log "FATAL: 渲染后仍有未填占位符：$left（$SRC）"; exit 5; fi
    printf '%s\n' "$out" > "$UNIT"
    systemctl daemon-reload
    systemctl enable --now eye-server
  fi
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
log "⚠️ 眼睛只往 $EYE_NOTES 追加；下游（superagent 源）只读，不许改历史行"
verify || log "提示：/health 不通先看 DISPLAY / 视觉模型 key；笔记不涨看节流与 SKIP 判定"
