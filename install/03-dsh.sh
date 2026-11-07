#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 03 · 平台 + web profile + 热装器
#
#   sudo bash install/03-dsh.sh --dry-run
#   sudo bash install/03-dsh.sh --yes
#   bash install/03-dsh.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [03]
# 验收（docs/04-deploy.md 路线 B 表 03 行）：面板可达；热装器能装卸插件
#
# 做四件事：
#   1) npm 全局装 @deepseek-ai/dsh@${DSH_VERSION}（版本固定，不装 latest）
#   2) profile 目录：cordis.yml 保持 []，cordis.patch.yml 由 deploy/ 示例渲染
#   3) systemd 单元 deploy/systemd/dsh-web.service.in → dsh-web.service
#   4) 打开热装器两个工具（cordis.patch.yml §1 已含，这里只验证是否生效）
#
# 用到的 env：DSH_VERSION DSH_HOME DSH_WEB_PORT PROFILE_WEB DSH_HEAP_MAX
#             DSH_MEMORY_MAX SERVICE_USER HOST_TAILSCALE 及 cordis 模板里的全部 ${...}
# ---------------------------------------------------------------------------
set -euo pipefail
NN=03
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

DSH_VERSION="${DSH_VERSION:-0.2.1-rc.2}"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE_WEB="${PROFILE_WEB:-web}"
DSH_WEB_PORT="${DSH_WEB_PORT:-3080}"
SERVICE_USER="${SERVICE_USER:-feiyu}"
PROF_DIR="$DSH_HOME/profiles/$PROFILE_WEB"
UNIT=/etc/systemd/system/dsh-web.service
NODE_BIN="$(command -v node || true)"
DSH_BIN="$(command -v dsh || true)"
HEAP_MAX_MB="${DSH_HEAP_MAX:-640M}"; HEAP_MAX_MB="${HEAP_MAX_MB%[Mm]}"
MEMORY_MAX="${DSH_MEMORY_MAX:-896M}"

# 模板占位符 @NAME@ → env
render_at() {
  local src="$1" dst="$2" missing=""
  local out; out="$(cat "$src")"
  while IFS= read -r key; do
    local val="${!key:-}"
    if [ -z "$val" ]; then missing="$missing $key"; else out="${out//@$key@/$val}"; fi
  done < <(grep -oE '@[A-Z0-9_]+@' "$src" | tr -d '@' | sort -u)
  if [ -n "$missing" ]; then
    log "FATAL: 模板 $src 缺少 env：$missing"
    exit 4
  fi
  # 装前断言：渲染完还有 @X@ 就拒绝安装（空值绝不带进 systemd 的 ${...}）
  local left
  left="$(printf '%s' "$out" | grep -oE '@[A-Z0-9_]+@' | sort -u | tr '\n' ' ' || true)"
  if [ -n "$left" ]; then
    log "FATAL: 渲染后仍有未填占位符：$left（模板 $src）"
    exit 5
  fi
  printf '%s\n' "$out" > "$dst"
}

# cordis 模板 ${NAME} → env；渲染后仍有 ${...} 就报错（不许半填）
render_cordis() {
  local src="$1" dst="$2"
  "$PYBIN" - "$src" "$dst" <<'PY'
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
  if [ -n "$DSH_BIN" ] && "$DSH_BIN" -v >/dev/null 2>&1; then
    log "verify ok: dsh $("$DSH_BIN" -v 2>/dev/null | head -1)"
  else
    log "verify FAIL: dsh 不可用"; fail=1
  fi

  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$DSH_WEB_PORT" || true)"
  if [ "$code" != "000" ] && [ -n "$code" ]; then
    log "verify ok: 面板 http://127.0.0.1:$DSH_WEB_PORT 返回 $code"
  else
    log "verify FAIL: 面板 $DSH_WEB_PORT 不可达（systemctl status dsh-web）"; fail=1
  fi

  if [ -f "$PROF_DIR/cordis.yml" ]; then
    log "verify ok: $PROF_DIR/cordis.yml 存在"
  else
    log "verify FAIL: $PROF_DIR/cordis.yml 不存在"; fail=1
  fi

  if [ -f "$PROF_DIR/cordis.patch.yml" ]; then
    local left
    left="$(grep -oE '\$\{[A-Z0-9_]+\}' "$PROF_DIR/cordis.patch.yml" | sort -u | tr '\n' ' ' || true)"
    if [ -z "$left" ]; then log "verify ok: cordis.patch.yml 已渲染（无残留占位符）"
    else log "verify FAIL: cordis.patch.yml 还有未填占位符：$left"; fail=1; fi
    if grep -q 'tool-plugin-manager' "$PROF_DIR/cordis.patch.yml"; then
      log "verify ok: 热装器工具（plugin-manager）在补丁层里已放开"
    else
      log "verify INFO: 补丁层没写 plugin-manager（面板里装卸插件会受限）"
    fi
  else
    log "verify FAIL: cordis.patch.yml 不存在"; fail=1
  fi

  if systemctl is-active --quiet dsh-web 2>/dev/null; then
    log "verify ok: dsh-web.service active"
  else
    log "verify INFO: dsh-web.service 未 active（本地调试可用前台 dsh web）"
  fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

# 03 允许非 root：npm 全局装到用户目录、单元写到 /etc 才需要 root
if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  log "WARN: 非 root —— npm 全局安装可能因权限失败；写 /etc/systemd/system 需要 root"
fi

# --- 03.1 平台 -------------------------------------------------------------
if [ -n "$DSH_BIN" ] && "$DSH_BIN" -v 2>/dev/null | grep -q "$DSH_VERSION"; then
  log "SKIP: dsh 已是 $DSH_VERSION"
else
  command -v npm >/dev/null 2>&1 || fatal "缺少 npm"
  log "安装 @deepseek-ai/dsh@$DSH_VERSION"
  run npm install -g "@deepseek-ai/dsh@$DSH_VERSION"
  DSH_BIN="$(command -v dsh || true)"
fi
[ -n "$NODE_BIN" ] || fatal "找不到 node（Node >= 20）"

# --- 03.2 profile ----------------------------------------------------------
log "profile 目录 $PROF_DIR"
run mkdir -p "$PROF_DIR"
if [ -f "$PROF_DIR/cordis.yml" ]; then
  log "SKIP: cordis.yml 已存在（保持 []，不要往里写内容）"
else
  run bash -c "printf '[]\n' > '$PROF_DIR/cordis.yml'"
fi

if [ -f "$PROF_DIR/cordis.patch.yml" ]; then
  log "SKIP: cordis.patch.yml 已存在（绝不覆盖；要重渲染先备份再删）"
else
  SRC="$REPO_DIR/deploy/cordis.patch.yml.example"
  [ -f "$SRC" ] || fatal "找不到 $SRC"
  if [ "$DRY" = 1 ]; then
    log "would: 渲染 $SRC → $PROF_DIR/cordis.patch.yml"
  else
    left="$(render_cordis "$SRC" "$PROF_DIR/cordis.patch.yml")"
    if [ -n "$left" ]; then
      log "FATAL: .env 缺少这些键，配置文件没有渲染完整：$left"
      log "       补齐后删掉 $PROF_DIR/cordis.patch.yml 重跑本步"
      exit 4
    fi
    chmod 600 "$PROF_DIR/cordis.patch.yml"
    log "已渲染 cordis.patch.yml（权限 600）"
  fi
fi

# --- 03.3 systemd 单元 -----------------------------------------------------
if [ -f "$UNIT" ]; then
  log "SKIP: $UNIT 已存在"
else
  SRC="$REPO_DIR/deploy/systemd/dsh-web.service.in"
  [ -f "$SRC" ] || fatal "找不到 $SRC"
  if [ "$DRY" = 1 ]; then
    log "would: 渲染 $SRC → $UNIT 并 systemctl enable --now dsh-web"
  else
    export PROFILE_WEB SERVICE_USER DSH_HOME ENV_FILE NODE_BIN DSH_BIN HEAP_MAX_MB MEMORY_MAX
    render_at "$SRC" "$UNIT"
    systemctl daemon-reload
    systemctl enable --now dsh-web
  fi
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
log "热装器自检（人工）：面板 → 插件 → 装一个空插件 → 卸掉；日志里应看到 plugin install/remove"
verify || log "提示：面板不通先 journalctl -u dsh-web -n 100"
