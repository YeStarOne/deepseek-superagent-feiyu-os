#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 08 · superagent（orchestrator + 玩具源 + keeper）
#
#   sudo bash install/08-superagent.sh --dry-run
#   sudo bash install/08-superagent.sh --yes
#   bash install/08-superagent.sh --verify
#
# 契约：install/README.md —— 幂等 / 失败即停 / 配置全走 env / stderr 前缀 [08]
# 验收（docs/04-deploy.md 路线 B 表 08 行）：would_accept 有记录；杀进程被拉起
#
# 依赖 03（平台）+ 04（记忆库）。
# ⚠️ 边界：eval.mode / sources / executor.prepare / outbox 都**不是** profile
#   patch 的键，它们在 stateDir 的状态库里（面板 / API 改）。本脚本只做三件：
#   起 orchestrator、装 examples 里的玩具源、把 eval.mode 停在 observe。
#
# 用到的 env：WORKSPACE SUPERAGENT_HOME PYTHON_BIN SERVICE_USER DSH_ORCH_PORT
#             PROFILE_SUPERAGENT SUPERAGENT_STATE_DIR SUPERAGENT_MEMORY_MAX ENV_FILE
# ---------------------------------------------------------------------------
set -euo pipefail
NN=08
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
SUPERAGENT_HOME="${SUPERAGENT_HOME:-$WORKSPACE/superagent}"
PROFILE_SUPERAGENT="${PROFILE_SUPERAGENT:-superagent}"
DSH_ORCH_PORT="${DSH_ORCH_PORT:-3082}"
SUPERAGENT_STATE_DIR="${SUPERAGENT_STATE_DIR:-$SUPERAGENT_HOME/state}"
SUPERAGENT_MEMORY_MAX="${SUPERAGENT_MEMORY_MAX:-512M}"
SERVICE_USER="${SERVICE_USER:-feiyu}"
UNIT=/etc/systemd/system/dsh-superagent.service

verify() {
  local fail=0
  if systemctl is-active --quiet dsh-superagent 2>/dev/null; then
    log "verify ok: dsh-superagent.service active"
  else
    log "verify FAIL: dsh-superagent.service 未 active"; fail=1
  fi

  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$DSH_ORCH_PORT" || true)"
  if [ "$code" != "000" ] && [ -n "$code" ]; then
    log "verify ok: orchestrator 面板 127.0.0.1:$DSH_ORCH_PORT 返回 $code"
  else
    log "verify FAIL: orchestrator 端口不通（注意它必须绑 loopback）"; fail=1
  fi

  # would_accept：玩具源产出（observe 模式的唯一价值就在这一条记录）
  local hits
  hits="$(grep -rl 'would_accept' "$SUPERAGENT_STATE_DIR" "$WORKSPACE/state" 2>/dev/null | head -3 || true)"
  if [ -n "$hits" ]; then
    log "verify ok: 找到 would_accept 记录"
    printf '%s\n' "$hits" | sed 's/^/  | /' >&2
    grep -h 'would_accept' $hits 2>/dev/null | tail -2 | sed 's/^/  | /' >&2 || true
  else
    log "verify FAIL: 没有 would_accept 记录（玩具源没跑 / 没装）"; fail=1
  fi

  # 杀进程被拉起：由 systemd Restart=always 提供，断言配置而不是真杀
  local rs
  rs="$(systemctl show -p Restart --value dsh-superagent 2>/dev/null || true)"
  if [ "$rs" = "always" ]; then log "verify ok: Restart=always（进程被杀会被拉起）"
  else log "verify FAIL: Restart=$rs（应为 always）"; fail=1; fi
  return $fail
}

if [ "$VERIFY" = 1 ]; then verify; exit $?; fi

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  fatal "需要 root 写 systemd 单元：sudo bash install/$NN-superagent.sh $*"
fi

if [ ! -x "$SUPERAGENT_HOME/scripts/dsh-superagent" ]; then
  if [ "$DRY" = 1 ]; then
    log "would: 需要 $SUPERAGENT_HOME/scripts/dsh-superagent（superagent 不在本仓）"
  else
    fatal "缺 $SUPERAGENT_HOME/scripts/dsh-superagent 可执行文件（superagent 不在本仓，先放到 $SUPERAGENT_HOME）"
  fi
fi
run mkdir -p "$SUPERAGENT_STATE_DIR"

# --- 08.1 superagent profile 补丁层（webserver 必须 loopback） -------------
PROF_DIR="${DSH_HOME:-$HOME/.dsh}/profiles/$PROFILE_SUPERAGENT"
run mkdir -p "$PROF_DIR"
if [ -f "$PROF_DIR/cordis.patch.yml" ]; then
  log "SKIP: superagent profile 补丁层已存在"
else
  if [ "$DRY" = 1 ]; then
    log "would: 写 $PROF_DIR/cordis.patch.yml（webserver host=127.0.0.1 port=$DSH_ORCH_PORT）"
  else
    cat > "$PROF_DIR/cordis.patch.yml" <<YAML
# superagent profile（install/08 生成）
# ⚠️ webserver 必须绑 loopback：主 bundle 有硬约束
#    "Orchestrator management requires a loopback Web server"。
- id: webserver
  config:
    host: 127.0.0.1
    port: ${DSH_ORCH_PORT}

- id: dsh-superagent
  config:
    stateDir: ${SUPERAGENT_STATE_DIR}
YAML
    chmod 600 "$PROF_DIR/cordis.patch.yml"
    log "已写 superagent profile 补丁层"
  fi
fi

# --- 08.2 系统单元 ---------------------------------------------------------
if [ -f "$UNIT" ]; then
  log "SKIP: $UNIT 已存在"
else
  SRC="$REPO_DIR/deploy/systemd/dsh-superagent.service.in"
  [ -f "$SRC" ] || fatal "找不到 $SRC"
  if [ "$DRY" = 1 ]; then
    log "would: 渲染 $SRC → $UNIT 并 systemctl enable --now dsh-superagent"
  else
    out="$(cat "$SRC")"; missing=""
    for key in SERVICE_USER SUPERAGENT_HOME ENV_FILE DSH_ORCH_PORT PROFILE_SUPERAGENT SUPERAGENT_MEMORY_MAX; do
      val="${!key:-}"
      if [ -z "$val" ]; then missing="$missing $key"; else out="${out//@$key@/$val}"; fi
    done
    [ -z "$missing" ] || fatal "模板缺 env：$missing"
    printf '%s\n' "$out" > "$UNIT"
    systemctl daemon-reload
    systemctl enable --now dsh-superagent
  fi
fi

log "DONE"
if [ "$DRY" = 1 ]; then log "dry-run 结束（未改动任何东西）"; exit 0; fi
log "策略（面板里改，不写配置）：eval.mode 先 observe → 复核记录过的决策 → 再考虑 auto"
log "玩具源：装 examples/ 里那个，先让 would_accept 有记录再谈真实业务"
verify || log "提示：端口不通看它是否绑到非 loopback；would_accept 不来先确认玩具源装着"
