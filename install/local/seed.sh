#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 种子：本地最快跑通（默认无服务器、无 QQ 也能装到"脑+记忆"）
#
#   bash install/local/seed.sh --dry-run     # 先看会做什么
#   bash install/local/seed.sh --yes         # 实装
#   ~/.feiyu/bin/start.sh                    # 起
#   ~/.feiyu/bin/doctor.sh                   # 体检
#
# 契约：幂等 / 失败即停 / 配置全走 env / 不打印任何凭据
# ---------------------------------------------------------------------------
set -euo pipefail

log() { printf '[seed] %s\n' "$*" >&2; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[ -f "$REPO_DIR/env.example" ] || { log "FATAL: 找不到 $REPO_DIR/env.example（请在仓库内运行）"; exit 2; }

FEIYU_HOME="${FEIYU_HOME:-$HOME/.feiyu}"
DSH_VERSION="${DSH_VERSION:-0.2.1-rc.2}"

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

verify() {
  local fail=0
  if command -v node >/dev/null 2>&1; then log "verify ok: node $(node -v)"; else log "verify FAIL: node 缺失"; fail=1; fi
  if command -v dsh >/dev/null 2>&1; then
    probe="$(dsh --version 2>/dev/null | head -1 || true)"
    if [ -n "$probe" ] && [[ "$probe" != error:* ]]; then log "verify ok: dsh $probe"; else log "verify FAIL: dsh 假活（exit 0 但零输出/报错，见 M2）"; fail=1; fi
  else log "verify FAIL: dsh 不可用"; fail=1; fi
  if [ -f "$FEIYU_HOME/.env" ]; then log "verify ok: .env 就位"; else log "verify FAIL: $FEIYU_HOME/.env 不存在"; fail=1; fi
  if [ -d "$FEIYU_HOME/memory-data" ]; then log "verify ok: memory-data 目录在"; else log "verify FAIL: memory-data 不在"; fail=1; fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

# --- A0 环境预检 -------------------------------------------------------------
log "A0 环境预检"
need() { command -v "$1" >/dev/null 2>&1 || { log "FATAL: 缺少 $1（$2）"; exit 3; }; }
need git      "https://git-scm.com"
need node     "Node.js >= 20, https://nodejs.org"
need npm      "随 Node 一起安装"

# python 命令名跨平台不一致：python3 / python / py -3 都认
PYBIN=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1; then
    if [ "$c" = "py" ]; then
      py -3 -c 'import sys; raise SystemExit(0 if sys.version_info>=(3,10) else 1)' >/dev/null 2>&1 && PYBIN="py -3" && break
    else
      "$c" -c 'import sys; raise SystemExit(0 if (sys.version_info[0],sys.version_info[1])>=(3,10) else 1)' >/dev/null 2>&1 && PYBIN="$c" && break
    fi
  fi
done
[ -n "$PYBIN" ] || log "WARN: 没找到 Python >= 3.10（工具脚本与体检要用；继续安装，稍后补装）"
log "python 解释器：${PYBIN:-<缺>}"

[ "$(node -p 'process.versions.node.split(".")[0]')" -ge 20 ] || { log "FATAL: Node $(node -v) 过旧，需要 >= 20"; exit 3; }

# --- A1 脚手架 + .env --------------------------------------------------------
log "A1 脚手架 $FEIYU_HOME"
run mkdir -p "$FEIYU_HOME/bin" "$FEIYU_HOME/logs" "$FEIYU_HOME/memory-data" "$FEIYU_HOME/plugins"
if [ -f "$FEIYU_HOME/.env" ]; then
  log "SKIP: .env 已存在（绝不覆盖）"
else
  if [ "$DRY" = 1 ]; then log "would: 复制 env.example -> $FEIYU_HOME/.env"
  else
    cp "$REPO_DIR/env.example" "$FEIYU_HOME/.env"
    chmod 600 "$FEIYU_HOME/.env" 2>/dev/null || true
    log "已生成 $FEIYU_HOME/.env —— 至少填 API_KEY / API_BASE / MODEL_MAIN"
  fi
fi

# --- A2 平台 -----------------------------------------------------------------
log "A2 平台 @deepseek-ai/dsh@$DSH_VERSION"
if command -v dsh >/dev/null 2>&1 && dsh -v >/dev/null 2>&1; then
  # M2 活性探测：dsh CLI 在 Node 下可能 exit 0 但零输出/报错（bin.js 的 import.meta.main 守卫是 Deno/Bun 语义）——假活会让 dsh web 假装启动
  probe="$(dsh --version 2>/dev/null | head -1 || true)"
  if [ -z "$probe" ] || [[ "$probe" == error:* ]]; then
    log "FATAL: dsh CLI 假活（exit 0 但零输出）——已知仓库级缺陷：bin.js 入口守卫 if (import.meta.main) 在 Node 下恒 false"
    log "  处置：安装 Bun（https://bun.sh）后用 'bun dsh ...' 调用，或向上游确认 Node 版本兼容性"
    exit 4
  fi
  log "SKIP: dsh 已安装且活性正常（$probe）；换版本：npm i -g @deepseek-ai/dsh@$DSH_VERSION"
else
  run npm install -g "@deepseek-ai/dsh@$DSH_VERSION"
fi

# --- A3 起停/体检脚本（自包含：运行时自己读 .env 与默认值） ---------------------
log "A3 生成 $FEIYU_HOME/bin/{start,stop,doctor}.sh"
if [ "$DRY" = 1 ]; then
  log "would: 写入 start.sh / stop.sh / doctor.sh"
else
  cat > "$FEIYU_HOME/bin/start.sh" <<'EOF'
#!/usr/bin/env bash
# 前台启动（Ctrl+C 停）。24/7 在线走服务器路线 B（docs/04-deploy.md）。
set -euo pipefail
FEIYU_HOME="${FEIYU_HOME:-$HOME/.feiyu}"
[ -f "$FEIYU_HOME/.env" ] && . "$FEIYU_HOME/.env" || true
DSH_HOST="${DSH_HOST:-127.0.0.1}"
DSH_PORT="${DSH_WEB_PORT:-3080}"
DSH_HEAP_MB="${DSH_HEAP_MAX_MB:-640}"
# 独立 DSH home：避开共享 ~/.dsh 里旧版本第三方插件的 required-plugin 兼容冲突
export DSH_HOME="$FEIYU_HOME/dsh-home"
export NODE_OPTIONS="--max-old-space-size=$DSH_HEAP_MB"
exec dsh web --host "$DSH_HOST" --port "$DSH_PORT" --no-open
EOF

  cat > "$FEIYU_HOME/bin/stop.sh" <<'EOF'
#!/usr/bin/env bash
# 停本地 dsh web（匹配串兼容 npm-shim / dsh 包装的进程）
pkill -f "dsh web --host|dsh\.cmd|npm-shim" && echo "stopped" || echo "no running dsh web found"
EOF

  cat > "$FEIYU_HOME/bin/doctor.sh" <<'EOF'
#!/usr/bin/env bash
# 本地体检（只读不修）。接了团队网后升级为 scripts/doctor.py 三绿版。
set -uo pipefail
FEIYU_HOME="${FEIYU_HOME:-$HOME/.feiyu}"
DSH_HOST="${DSH_HOST:-127.0.0.1}"
DSH_PORT="${DSH_WEB_PORT:-3080}"
ok=0; bad=0
say_ok() { printf '  OK   %s\n' "$1"; ok=$((ok+1)); }
say_bad() { printf '  FAIL %s\n' "$1"; bad=$((bad+1)); }

if command -v node >/dev/null 2>&1 && [ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge 20 ]; then say_ok "node >= 20 在位"; else say_bad "node >= 20 在位"; fi
if command -v dsh >/dev/null 2>&1 && probe="$(dsh --version 2>/dev/null | head -1 || true)" && [ -n "$probe" ] && [[ "$probe" != error:* ]]; then say_ok "dsh 可用（$probe）"; else say_bad "dsh 可用（exit 0 但零输出/报错=假活，见 M2）"; fi
if [ -f "$FEIYU_HOME/.env" ]; then say_ok ".env 就位"; else say_bad ".env 就位"; fi
if touch "$FEIYU_HOME/memory-data/.probe" 2>/dev/null; then rm -f "$FEIYU_HOME/memory-data/.probe"; say_ok "memory-data 可写"; else say_bad "memory-data 可写"; fi
# 面板配对锁阶段 401/403 是正常状态（等待 token 配对），不算 FAIL
if curl -s -o /dev/null -w '%{http_code}' "http://$DSH_HOST:$DSH_PORT" | grep -qE '^(200|301|302|401|403)$'; then say_ok "面板可连 $DSH_HOST:$DSH_PORT"; else say_bad "面板可连 $DSH_HOST:$DSH_PORT（没起就先 start.sh）"; fi
if ls "$FEIYU_HOME/memory-data" 2>/dev/null | grep -qv '.probe'; then say_ok "memory-data 有内容"; else say_bad "memory-data 还是空的（先完成 A3 记忆库初始化）"; fi

printf '  —— %d 项通过，%d 项未过。未过的看 docs/04-deploy.md 对应步骤。\n' "$ok" "$bad"
[ "$bad" -eq 0 ]
EOF
  chmod +x "$FEIYU_HOME/bin/"*.sh
fi

# --- 收尾 --------------------------------------------------------------------
if [ "$DRY" = 1 ]; then
  log "dry-run 结束，没有改动任何东西。加 --yes 实装。"
else
  verify || log "提示：FAIL 项看 docs/04-deploy.md 对应步骤（A0–A3）。"
  log "完成。下一步："
  log "  1) 编辑 $FEIYU_HOME/.env，至少填 API_KEY / API_BASE / MODEL_MAIN"
  log "  2) $FEIYU_HOME/bin/start.sh    # 前台起，浏览器开 http://127.0.0.1:${DSH_WEB_PORT:-3080}"
  log "  3) $FEIYU_HOME/bin/doctor.sh   # 体检"
  log "  可选加餐（docs/04-deploy.md 路线 A）：A4 superagent / A5 团队网 / A6 QQ 聊天线"
fi
