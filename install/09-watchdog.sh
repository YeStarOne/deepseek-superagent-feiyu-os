#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 09 · 看护 + 健康检查 + 报表
#
#   sudo bash install/09-watchdog.sh --dry-run
#   sudo bash install/09-watchdog.sh --yes
#   bash install/09-watchdog.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [09]
# 验收（docs/04-deploy.md 路线 B 表 09 行）：杀进程 30 秒内被拉起
#
# 三层各管一段，别重复：
#   ① systemd Restart=always —— 进程死了立刻拉起（秒级）
#   ② health_check.sh（cron 10 分钟）—— 端口/库/日志还在动吗（假活：进程在但不干活）
#   ③ 报表（cron 每日）—— token 用量，给人看趋势
#
# 用到的 env：WORKSPACE PYTHON_BIN DSH_WEB_PORT EYE_PORT DSH_ORCH_PORT
#             MEMORY_DATA_DIR OUTBOX_MIN_INTERVAL
# ---------------------------------------------------------------------------
set -euo pipefail
NN=09
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
DSH_WEB_PORT="${DSH_WEB_PORT:-3080}"
EYE_PORT="${EYE_PORT:-8901}"
DSH_ORCH_PORT="${DSH_ORCH_PORT:-3082}"
MEMORY_DATA_DIR="${MEMORY_DATA_DIR:-$WORKSPACE/memory-data}"
BIN="$WORKSPACE/bin"
MARK='# feiyu-install:09'

verify() {
  local fail=0
  if [ -x "$BIN/health_check.sh" ]; then log "verify ok: $BIN/health_check.sh 在位"
  else log "verify FAIL: $BIN/health_check.sh 缺失"; fail=1; fi
  if [ -x "$BIN/backup.sh" ]; then log "verify ok: $BIN/backup.sh 在位"
  else log "verify FAIL: $BIN/backup.sh 缺失"; fail=1; fi

  if crontab -l 2>/dev/null | grep -qF "$MARK"; then
    log "verify ok: cron 已装"
    crontab -l 2>/dev/null | grep -A3 -F "$MARK" | sed 's/^/  | /' >&2 || true
  else
    log "verify FAIL: cron 未装（标记 $MARK）"; fail=1
  fi

  local rs
  for u in dsh-web eye-server dsh-superagent dsh-outbox-qq; do
    rs="$(systemctl show -p Restart --value "$u" 2>/dev/null || true)"
    if [ "$rs" = "always" ]; then log "verify ok: $u Restart=always"
    else log "verify INFO: $u Restart=${rs:-未安装}（未装的步骤跳过）"; fi
  done

  log "真杀测试（30s 内应被拉起，人工执行）："
  log "  sudo systemctl kill -s KILL dsh-web && sleep 30 && systemctl is-active dsh-web"
  if [ -x "$BIN/health_check.sh" ]; then
    log "verify: 现在跑一次健康检查（真实输出）"
    "$BIN/health_check.sh" 2>&1 | sed 's/^/  | /' >&2 || true
  fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

run mkdir -p "$BIN" "$WORKSPACE/logs"

# --- 09.1 health_check.sh --------------------------------------------------
if [ -f "$BIN/health_check.sh" ]; then
  log "SKIP: $BIN/health_check.sh 已存在"
else
  log "生成 $BIN/health_check.sh"
  if [ "$DRY" = 1 ]; then
    log "would: 写 health_check.sh（面板/眼睛/orchestrator 端口 + 记忆库时间戳）"
  else
    cat > "$BIN/health_check.sh" <<'EOF'
#!/usr/bin/env bash
# 健康检查：只读不修；异常才输出（cron 静默友好）
set -uo pipefail
FEIYU_HOME="${FEIYU_HOME:-$HOME/.feiyu}"
WORKSPACE="${WORKSPACE:-$HOME/work}"
DSH_WEB_PORT="${DSH_WEB_PORT:-3080}"
EYE_PORT="${EYE_PORT:-8901}"
DSH_ORCH_PORT="${DSH_ORCH_PORT:-3082}"
MEMORY_DATA_DIR="${MEMORY_DATA_DIR:-$WORKSPACE/memory-data}"
[ -f "$FEIYU_HOME/.env" ] && . "$FEIYU_HOME/.env" || true
bad=0
probe() { # name url
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "$2" || true)"
  if [ "$code" = "000" ] || [ -z "$code" ]; then echo "FAIL $1 $2 不可达"; bad=$((bad+1)); fi
}
probe panel "http://127.0.0.1:$DSH_WEB_PORT"
probe eyes  "http://127.0.0.1:$EYE_PORT/health"
probe orch  "http://127.0.0.1:$DSH_ORCH_PORT"

# 假活判据：记忆库最近一次写入时间戳（进程活着但库不涨 = 断档）
if [ -d "$MEMORY_DATA_DIR" ]; then
  newest="$(find "$MEMORY_DATA_DIR" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f1)"
  if [ -n "$newest" ]; then
    age_h=$(( ( $(date +%s) - ${newest%.*} ) / 3600 ))
    [ "$age_h" -gt 48 ] && { echo "WARN 记忆库 ${age_h}h 没更新（假活？）"; bad=$((bad+1)); }
  else
    echo "WARN 记忆库还是空的"; bad=$((bad+1))
  fi
fi
[ "$bad" -eq 0 ] && exit 0 || exit 1
EOF
    chmod +x "$BIN/health_check.sh"
  fi
fi

# --- 09.2 backup.sh --------------------------------------------------------
if [ -f "$BIN/backup.sh" ]; then
  log "SKIP: $BIN/backup.sh 已存在"
else
  log "生成 $BIN/backup.sh"
  if [ "$DRY" = 1 ]; then
    log "would: 写 backup.sh（tar 记忆库 + .env，只增不改，保留 14 份）"
  else
    cat > "$BIN/backup.sh" <<'EOF'
#!/usr/bin/env bash
# 备份：只增不改，保留最近 14 份
set -euo pipefail
FEIYU_HOME="${FEIYU_HOME:-$HOME/.feiyu}"
WORKSPACE="${WORKSPACE:-$HOME/work}"
MEMORY_DATA_DIR="${MEMORY_DATA_DIR:-$WORKSPACE/memory-data}"
DEST="${BACKUP_DIR:-$WORKSPACE/backups}"
mkdir -p "$DEST"
stamp="$(date +%Y%m%d-%H%M)"
tar -czf "$DEST/feiyu-$stamp.tgz" -C "$(dirname "$MEMORY_DATA_DIR")" "$(basename "$MEMORY_DATA_DIR")" 2>/dev/null
[ -f "$FEIYU_HOME/.env" ] && tar -czf "$DEST/env-$stamp.tgz" -C "$FEIYU_HOME" .env
ls -1t "$DEST"/feiyu-*.tgz 2>/dev/null | tail -n +15 | xargs -r rm -f
echo "backup ok: $DEST (feiyu-$stamp.tgz)"
EOF
    chmod +x "$BIN/backup.sh"
  fi
fi

# --- 09.3 cron -------------------------------------------------------------
if crontab -l 2>/dev/null | grep -qF "$MARK"; then
  log "SKIP: cron 已装"
else
  CRON_SRC="$REPO_DIR/deploy/cron/crontab.example"
  [ -f "$CRON_SRC" ] || fatal "找不到 $CRON_SRC"
  if [ "$DRY" = 1 ]; then
    log "would: 从 $CRON_SRC 渲染 health_check / token 报表两行写入 crontab"
  else
    rendered="$(sed -e "s|@PYTHON_BIN@|$PYTHON_BIN|g" -e "s|@WORKSPACE@|$WORKSPACE|g" "$CRON_SRC" \
      | grep -E 'health_check|token_usage_report')"
    left="$(printf '%s' "$rendered" | grep -oE '@[A-Z0-9_]+@' | sort -u | tr '\n' ' ' || true)"
    if [ -n "$left" ]; then log "FATAL: cron 渲染后仍有未填占位符：$left（$CRON_SRC）"; exit 5; fi
    TMP="$(mktemp)"
    {
      crontab -l 2>/dev/null || true
      echo "$MARK"
      printf '%s\n' "$rendered"
    } > "$TMP"
    crontab "$TMP"; rm -f "$TMP"
    log "cron 已装"
  fi
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
verify || log "提示：cron 不跑先查 cron 服务；健康检查输出写到 $WORKSPACE/logs/health.log"
