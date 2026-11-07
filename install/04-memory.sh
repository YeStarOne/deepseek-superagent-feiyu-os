#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 04 · 记忆引擎 + 空库 + 蒸馏/备份 cron
#
#   sudo bash install/04-memory.sh --dry-run
#   sudo bash install/04-memory.sh --yes
#   bash install/04-memory.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [04]
# 验收（docs/04-deploy.md 路线 B 表 04 行）：写入一条并检索回来
#
# ⚠️ 关于验收：写入/检索是**运行时**行为（要模型与向量服务都在线）。
#   本脚本的默认 --verify 做四件可离线验的事：kit 在位 / 库目录可写 /
#   补丁层 wiring 完整 / cron 已装，并用真实输出打印引擎导出的 API 面。
#   要跑"真写入真检索"，把探针命令放 env：MEMORY_PROBE_CMD="node /path/probe.mjs"，
#   --verify 会原样执行并打印它的输出（失败即非 0 退出）。
#
# 用到的 env：WORKSPACE MEMORY_KIT_DIR MEMORY_DATA_DIR MEMORY_PLUGIN_REPO
#             MEMORY_PLUGIN_REF PROFILE_WEB MEMORY_EMBED_MODEL MEMORY_EMBED_DIM
#             MEMORY_EMBED_BASE_URL MEMORY_EMBED_API_KEY_ENV MEMORY_SUMMARY_MODEL
#             MEMORY_SUMMARY_BASE_URL MEMORY_SUMMARY_API_KEY_ENV PYTHON_BIN
# ---------------------------------------------------------------------------
set -euo pipefail
NN=04
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
MEMORY_KIT_DIR="${MEMORY_KIT_DIR:-$HOME/.dsh/feiyu-memory}"
MEMORY_DATA_DIR="${MEMORY_DATA_DIR:-$WORKSPACE/memory-data}"
PROFILE_WEB="${PROFILE_WEB:-web}"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROF_DIR="$DSH_HOME/profiles/$PROFILE_WEB"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || echo python3)}"
MARK='# feiyu-install:04'

render_cordis() {
  local src="$1" dst="$2"
  python3 - "$src" "$dst" <<'PY'
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
  if [ -d "$MEMORY_KIT_DIR" ]; then log "verify ok: kit 在位 $MEMORY_KIT_DIR"
  else log "verify FAIL: kit 不在 $MEMORY_KIT_DIR"; fail=1; fi

  if mkdir -p "$MEMORY_DATA_DIR" 2>/dev/null && [ -w "$MEMORY_DATA_DIR" ]; then
    log "verify ok: 库目录可写 $MEMORY_DATA_DIR"
    local n; n="$(find "$MEMORY_DATA_DIR" -maxdepth 2 -name '*.jsonl' 2>/dev/null | wc -l)"
    log "verify: 库内 jsonl 文件数 $n（0 = 还是空库，首次对话后应该 >0）"
  else
    log "verify FAIL: 库目录不可写 $MEMORY_DATA_DIR"; fail=1
  fi

  if [ -f "$PROF_DIR/cordis.patch.yml" ] && grep -qE '^\s*-?\s*id:\s*memory\b' "$PROF_DIR/cordis.patch.yml"; then
    log "verify ok: 补丁层有 memory 条目"
  else
    log "verify FAIL: 补丁层没有 memory 条目（$PROF_DIR/cordis.patch.yml）"; fail=1
  fi

  if crontab -l 2>/dev/null | grep -qF "$MARK"; then
    log "verify ok: cron 已装（标记 $MARK）"
    crontab -l 2>/dev/null | grep -F "$MARK" | sed 's/^/  | /' >&2 || true
  else
    log "verify FAIL: cron 未装（跑本步会从 deploy/cron/crontab.example 渲染安装）"; fail=1
  fi

  # 引擎导出面（真实输出，用于写探针/排障）
  local entry
  entry="$(python3 - "$MEMORY_KIT_DIR" <<'PY'
import json, os, sys
d = sys.argv[1]
p = os.path.join(d, 'package.json')
if not os.path.exists(p):
    print(''); raise SystemExit
j = json.load(open(p, encoding='utf-8'))
main = j.get('main') or 'index.js'
print(os.path.join(d, main))
PY
)"
  if [ -n "$entry" ] && [ -f "$entry" ] && command -v node >/dev/null 2>&1; then
    log "verify: 引擎导出（node -e 实跑）"
    node -e "const m=require(process.argv[1]);console.log('  exports: '+Object.keys(m).join(', '))" "$entry" 2>&1 | sed 's/^/  | /' >&2 || true
  fi

  if [ -n "${MEMORY_PROBE_CMD:-}" ]; then
    log "verify: 跑写入/检索探针 MEMORY_PROBE_CMD"
    if eval "$MEMORY_PROBE_CMD" 2>&1 | sed 's/^/  | /' >&2; then
      log "verify ok: 探针通过（写入并检索回来了）"
    else
      log "verify FAIL: 探针失败"; fail=1
    fi
  else
    log "verify INFO: 没给 MEMORY_PROBE_CMD —— 真写入/检索未验（见本文件头注释）"
  fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

# --- 04.1 kit --------------------------------------------------------------
PLUGIN_REPO="${MEMORY_PLUGIN_REPO:-https://github.com/YeStarOne/dsh-plugin-memory-graph.git}"
PLUGIN_REF="${MEMORY_PLUGIN_REF:-main}"
if [ -d "$MEMORY_KIT_DIR/.git" ]; then
  log "更新 kit（$PLUGIN_REF）"
  if [ "$DRY" = 1 ]; then log "would: git -C $MEMORY_KIT_DIR fetch --depth 1 origin $PLUGIN_REF && checkout FETCH_HEAD"
  else
    git -C "$MEMORY_KIT_DIR" fetch --depth 1 origin "$PLUGIN_REF"
    git -C "$MEMORY_KIT_DIR" checkout --detach FETCH_HEAD >/dev/null
  fi
elif [ -d "$MEMORY_KIT_DIR" ]; then
  log "SKIP: $MEMORY_KIT_DIR 已存在但不是 git 仓（当作用户自备，不动它）"
else
  log "clone kit ← $PLUGIN_REPO#$PLUGIN_REF"
  run git clone --depth 1 --branch "$PLUGIN_REF" "$PLUGIN_REPO" "$MEMORY_KIT_DIR"
fi

# --- 04.2 空库 -------------------------------------------------------------
run mkdir -p "$MEMORY_DATA_DIR"

# --- 04.3 补丁层 wiring ----------------------------------------------------
if [ ! -f "$PROF_DIR/cordis.patch.yml" ]; then
  if [ "$DRY" = 1 ]; then
    log "would: 需要 $PROF_DIR/cordis.patch.yml（先跑 03-dsh.sh）"
    log "dry-run 结束（未改动任何东西）"; exit 0
  fi
  fatal "缺 $PROF_DIR/cordis.patch.yml —— 先跑 03-dsh.sh"
fi
if grep -qE '^\s*-?\s*id:\s*memory\b' "$PROF_DIR/cordis.patch.yml"; then
  log "SKIP: 补丁层已有 memory 条目"
else
  log "往 cordis.patch.yml 追加 memory 条目"
  if [ "$DRY" = 1 ]; then
    log "would: 追加 memory 块（kitDir=$MEMORY_KIT_DIR dataDir=$MEMORY_DATA_DIR embed=${MEMORY_EMBED_MODEL:-}）"
  else
    cat > "$PROF_DIR/.memory-block.yml.tmp" <<'YAML'

# ── 记忆（install/04 追加） ────────────────────────────────────────────────
# 每个 chat 一个独立库，多使用者互不串味；召回在回合前拼进消息。
# ⚠️ 换 embedding 模型或维度必须重建向量并跑自检，否则召回静默变空。
- id: memory
  config:
    enabled: true
    kitDir: ${MEMORY_KIT_DIR}
    dataDir: ${MEMORY_DATA_DIR}
    chatModel: ${MEMORY_SUMMARY_MODEL}
    chatBaseUrl: ${MEMORY_SUMMARY_BASE_URL}
    chatApiKeyEnv: ${MEMORY_SUMMARY_API_KEY_ENV}
    embedModel: ${MEMORY_EMBED_MODEL}
    embedBaseUrl: ${MEMORY_EMBED_BASE_URL}
    embedApiKeyEnv: ${MEMORY_EMBED_API_KEY_ENV}
    dim: ${MEMORY_EMBED_DIM}
YAML
    left="$(render_cordis "$PROF_DIR/.memory-block.yml.tmp" "$PROF_DIR/.memory-block.yml")"
    rm -f "$PROF_DIR/.memory-block.yml.tmp"
    if [ -n "$left" ]; then
      fatal "memory 块渲染缺 env：$left（补齐后重跑本步）"
    fi
    cat "$PROF_DIR/.memory-block.yml" >> "$PROF_DIR/cordis.patch.yml"
    rm -f "$PROF_DIR/.memory-block.yml"
    chmod 600 "$PROF_DIR/cordis.patch.yml" 2>/dev/null || true
    log "已追加 memory 条目（重启 dsh-web 生效）"
  fi
fi

# --- 04.4 cron（蒸馏 / 备份 / 健康检查里的记忆那两条） ---------------------
CRON_SRC="$REPO_DIR/deploy/cron/crontab.example"
if crontab -l 2>/dev/null | grep -qF "$MARK"; then
  log "SKIP: cron 已装"
else
  [ -f "$CRON_SRC" ] || fatal "找不到 $CRON_SRC"
  if [ "$DRY" = 1 ]; then
    log "would: 从 $CRON_SRC 渲染 night_memory / backup 两行并写入 crontab（标记 $MARK）"
  else
    TMP_CRON="$(mktemp)"
    {
      crontab -l 2>/dev/null || true
      echo "$MARK"
      sed -e "s|@PYTHON_BIN@|$PYTHON_BIN|g" \
          -e "s|@WORKSPACE@|$WORKSPACE|g" \
          "$CRON_SRC" | grep -E 'night_memory|backup'
    } > "$TMP_CRON"
    crontab "$TMP_CRON"
    rm -f "$TMP_CRON"
    log "cron 已装"
  fi
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
log "自检（人工）：下一次对话后看 $MEMORY_DATA_DIR 是否出现 *.jsonl，且时间戳在涨"
verify || log "提示：补丁层改动要重启 dsh-web 才生效"
