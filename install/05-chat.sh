#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 05 · 聊天线接线 + 人设/AGENTS 模板
#
#   sudo bash install/05-chat.sh --dry-run
#   sudo bash install/05-chat.sh --yes
#   bash install/05-chat.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [05]
# 验收（docs/04-deploy.md 路线 B 表 05 行）：发一条消息得到回复（人工，脚本给命令）
#
# 依赖 02（OneBot 端口）+ 03（平台与 profile）。
#
# 用到的 env：PROFILE_WEB DSH_HOME WORKSPACE ONEBOT_WS HOST_TAILSCALE
#             ONEBOT_ACCESS_TOKEN OWNER_QQ PARTNER_QQ GROUP_QQ MODEL_MAIN
# ---------------------------------------------------------------------------
set -euo pipefail
NN=05
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

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE_WEB="${PROFILE_WEB:-web}"
PROF_DIR="$DSH_HOME/profiles/$PROFILE_WEB"
WORKSPACE="${WORKSPACE:-$HOME/work}"
ONEBOT_WS="${ONEBOT_WS:-ws://127.0.0.1:6098}"
OB_HOST="${ONEBOT_WS#*://}"; OB_HOST="${OB_HOST%%:*}"
OB_PORT="${ONEBOT_WS##*:}"; OB_PORT="${OB_PORT%%/*}"

render_cordis() {
  python3 - "$1" "$2" <<'PY'
import os, re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding='utf-8').read()
out = re.sub(r'\$\{([A-Z0-9_]+)\}', lambda m: os.environ.get(m.group(1), m.group(0)), text)
left = sorted(set(re.findall(r'\$\{([A-Z0-9_]+)\}', out)))
open(dst, 'w', encoding='utf-8').write(out)
print(','.join(left))
PY
}

verify() {
  local fail=0
  if grep -qE '^\s*-?\s*id:\s*dsh-onebot\b' "$PROF_DIR/cordis.patch.yml" 2>/dev/null; then
    log "verify ok: 补丁层有 dsh-onebot 条目"
  else
    log "verify FAIL: 补丁层没有 dsh-onebot（跑本步会追加）"; fail=1
  fi

  if timeout 3 bash -c "</dev/tcp/${OB_HOST}/${OB_PORT}" 2>/dev/null; then
    log "verify ok: OneBot 反向 WS $OB_HOST:$OB_PORT 可连"
  else
    log "verify FAIL: OneBot 端口不通（先跑 02-onebot.sh）"; fail=1
  fi

  for f in AGENTS.md; do
    if [ -f "$WORKSPACE/$f" ]; then log "verify ok: $WORKSPACE/$f 在位"
    else log "verify FAIL: $WORKSPACE/$f 缺失"; fail=1; fi
  done

  if grep -qE '^\s*-?\s*id:\s*agent-default-model' "$PROF_DIR/cordis.patch.yml" 2>/dev/null; then
    log "verify ok: 模型车道已配置（agent-default-model）"
  else
    log "verify INFO: 没配 agent-default-model（会用平台默认模型）"
  fi

  log "人工验收：给机器人发一条消息，应收到回复；回合中再插一条也应收到（steer）"
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

if [ ! -f "$PROF_DIR/cordis.patch.yml" ]; then
  if [ "$DRY" = 1 ]; then
    log "would: 需要 $PROF_DIR/cordis.patch.yml（先跑 03-dsh.sh）"
    log "dry-run 结束（未改动任何东西）"; exit 0
  fi
  fatal "缺 $PROF_DIR/cordis.patch.yml —— 先跑 03-dsh.sh"
fi

# --- 05.1 聊天线插件 -------------------------------------------------------
if grep -qE '^\s*-?\s*id:\s*dsh-onebot\b' "$PROF_DIR/cordis.patch.yml"; then
  log "SKIP: 补丁层已有 dsh-onebot"
else
  log "往 cordis.patch.yml 追加 dsh-onebot"
  if [ "$DRY" = 1 ]; then
    log "would: 追加 dsh-onebot 块（mode=reverse host=$OB_HOST port=$OB_PORT）"
  else
    TMP="$(mktemp)"
    cat > "$TMP" <<'YAML'

# ── 聊天线：OneBot 反向 WS（install/05 追加） ──────────────────────────────
# ⚠️ dmPolicy=open 的实际语义是「仅管理员可私聊」，要放行别人必须用 allowlist。
- id: dsh-onebot
  name: dsh-onebot-qq
  config:
    mode: reverse
    host: ${OB_HOST}
    port: ${OB_PORT}
    accessToken: ${ONEBOT_ACCESS_TOKEN}
    adminUsers: [ "${OWNER_QQ}" ]
    workspacePath: ${WORKSPACE}
    dmPolicy: allowlist
    allowFrom: [ "${OWNER_QQ}", "${PARTNER_QQ}" ]
    groupPolicy: allowlist
    groupAllowFrom: [ "${GROUP_QQ}" ]
    requireMention: false
    rateLimitPerMinute: 5
    newMessagePolicy: steer
    autoSteerPolicy: all
    interimMessages: true
    interimRecall: false
    textImageThreshold: 0
YAML
    OUT="$(mktemp)"
    OB_HOST="$OB_HOST" OB_PORT="$OB_PORT" left="$(render_cordis "$TMP" "$OUT")"
    rm -f "$TMP"
    if [ -n "$left" ]; then
      rm -f "$OUT"
      fatal "dsh-onebot 块渲染缺 env：$left"
    fi
    cat "$OUT" >> "$PROF_DIR/cordis.patch.yml"
    rm -f "$OUT"
    log "已追加（重启 dsh-web 生效）"
  fi
fi

# --- 05.2 人设 / AGENTS 模板 ----------------------------------------------
run mkdir -p "$WORKSPACE"
for pair in "persona.md:AGENTS.md" "HANDOFF.md:HANDOFF.md"; do
  src_name="${pair%%:*}"; dst_name="${pair##*:}"
  SRC="$REPO_DIR/templates/$src_name"
  DST="$WORKSPACE/$dst_name"
  if [ ! -f "$SRC" ]; then log "WARN: 模板不存在 $SRC（跳过）"; continue; fi
  if [ -f "$DST" ]; then
    log "SKIP: $DST 已存在（绝不覆盖）"
  else
    log "放模板 $SRC → $DST"
    run cp "$SRC" "$DST"
  fi
done

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
verify || log "提示：发消息没回复先看 journalctl -u dsh-web -n 100，再确认 OneBot 登录态"
