#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 06 · 出海通道（限速 + 幂等）
#
#   sudo bash install/06-outbox.sh --dry-run
#   sudo bash install/06-outbox.sh --yes
#   bash install/06-outbox.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [06]
# 验收（docs/04-deploy.md 路线 B 表 06 行）：测试 DM 真发到；重复不重发
#
# 依赖 05（聊天线通）。
# ⚠️ 幂等的落点是 outbox 自己的已发账本（<WORKSPACE>/state/outbox-sent.jsonl）：
#   同一条内容第二次入场必须被跳过 —— 验收就是看账本里同一 hash 只有一行。
#
# 用到的 env：WORKSPACE PYTHON_BIN SERVICE_USER OUTBOX_MIN_INTERVAL
#             OUTBOX_MEMORY_MAX ENV_FILE
# ---------------------------------------------------------------------------
set -euo pipefail
NN=06
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
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || echo python3)}"
SERVICE_USER="${SERVICE_USER:-feiyu}"
OUTBOX_MIN_INTERVAL="${OUTBOX_MIN_INTERVAL:-8}"
OUTBOX_MEMORY_MAX="${OUTBOX_MEMORY_MAX:-256M}"
OUTBOX_PY="$WORKSPACE/bin/outbox_qq.py"
LEDGER="$WORKSPACE/state/outbox-sent.jsonl"
LOG_DIR="$WORKSPACE/logs"
UNIT=/etc/systemd/system/dsh-outbox-qq.service

verify() {
  local fail=0
  local iv="${OUTBOX_MIN_INTERVAL:-0}"
  if [ "$iv" -ge 8 ] 2>/dev/null; then
    log "verify ok: 限速 $iv s（下限 8s，太快会被平台风控）"
  else
    log "verify FAIL: OUTBOX_MIN_INTERVAL=$iv < 8s"; fail=1
  fi

  if systemctl is-active --quiet dsh-outbox-qq 2>/dev/null; then
    log "verify ok: dsh-outbox-qq.service active"
  else
    log "verify FAIL: dsh-outbox-qq.service 未 active"; fail=1
  fi
  log "verify: 最近日志"
  journalctl -u dsh-outbox-qq -n 10 --no-pager 2>/dev/null | sed 's/^/  | /' >&2 || true

  if [ -f "$LEDGER" ]; then
    local dup
    dup="$("$PYTHON_BIN" - "$LEDGER" <<'PY'
import json, sys, collections
seen = collections.Counter()
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.strip()
    if not line:
        continue
    try:
        r = json.loads(line)
    except Exception:
        continue
    h = r.get('hash') or r.get('digest') or r.get('id')
    if h:
        seen[h] += 1
dups = {k: v for k, v in seen.items() if v > 1}
print(len(dups))
PY
)"
    log "verify: 已发账本 $(wc -l < "$LEDGER") 行，重复 hash $dup 个"
    if [ "$dup" = "0" ]; then log "verify ok: 无重复发送（幂等生效）"
    else log "verify FAIL: 账本里有 $dup 个重复 hash"; fail=1; fi
  else
    log "verify FAIL: 还没有账本 $LEDGER（没发过东西 / 路径不对）"; fail=1
  fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  fatal "需要 root 写 systemd 单元：sudo bash install/$NN-outbox.sh $*"
fi

# --- 06.1 前置 -------------------------------------------------------------
if [ ! -f "$OUTBOX_PY" ]; then
  if [ "$DRY" = 1 ]; then
    log "would: 需要 $OUTBOX_PY（出海脚本不在本仓，实现仓私有）"
  else
    fatal "缺 $OUTBOX_PY —— 出海脚本不在本仓（实现仓私有），先把可执行文件放到 $WORKSPACE/bin/"
  fi
fi
run mkdir -p "$LOG_DIR" "$(dirname "$LEDGER")"

# --- 06.2 systemd 单元 ----------------------------------------------------
if [ -f "$UNIT" ]; then
  log "SKIP: $UNIT 已存在"
else
  SRC="$REPO_DIR/deploy/systemd/dsh-outbox-qq.service.in"
  [ -f "$SRC" ] || fatal "找不到 $SRC"
  if [ "$DRY" = 1 ]; then
    log "would: 渲染 $SRC → $UNIT 并 systemctl enable --now dsh-outbox-qq"
  else
    out="$(cat "$SRC")"
    missing=""
    for key in SERVICE_USER WORKSPACE ENV_FILE PYTHON_BIN OUTBOX_MIN_INTERVAL OUTBOX_MEMORY_MAX; do
      val="${!key:-}"
      if [ -z "$val" ]; then missing="$missing $key"; else out="${out//@$key@/$val}"; fi
    done
    [ -z "$missing" ] || fatal "模板缺 env：$missing"
    left="$(printf '%s' "$out" | grep -oE '@[A-Z0-9_]+@' | sort -u | tr '\n' ' ' || true)"
    if [ -n "$left" ]; then log "FATAL: 渲染后仍有未填占位符：$left（$SRC）"; exit 5; fi
    printf '%s\n' "$out" > "$UNIT"
    systemctl daemon-reload
    systemctl enable --now dsh-outbox-qq
  fi
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
log "人工验收（幂等）：同一条内容入队两次 → 第二次应被跳过"
log "  $PYTHON_BIN $OUTBOX_PY --once   # 手动跑一轮；账本 $LEDGER 的 hash 不应增加"
verify || log "提示：发不出去先看 OneBot 登录态与 target 是否在 allowFrom 里"
