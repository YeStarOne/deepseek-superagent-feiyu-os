# install · 部署脚本

> **两条路**：
> - **本地（默认）**：直接用 [`local/seed.sh`](local/seed.sh) / [`local/seed.ps1`](local/seed.ps1)——不需要服务器、不需要 QQ，约 30 分钟。
> - **服务器（24/7，可选）**：下面的 NN 脚本，对应 [docs/04-deploy.md](../feiyu/docs/04-deploy.md) 路线 B。
>
> 规格先行：脚本可以换人写，契约不能换。

## 契约

```
install/NN-<name>.sh
  --dry-run     只打印将要做什么，不改系统
  --verify      只跑验收命令，打印真实输出
  --yes         非交互（CI / 自动化）
  幂等          重复执行结果相同；已完成的步骤直接跳过并打印 SKIP
  失败即停      set -euo pipefail；非 0 退出，不继续下一步
  日志          stderr，单行前缀 [NN]
  配置          一律从 env 读（见 ../env.example），脚本内不写死地址/路径
  装前断言      模板里残留 `@[A-Z_]+@`（未填）→ 拒绝安装，退出码 5；不把空值带进 systemd/cron
```

## 列表

| 脚本 | 装什么 | 验收（`--verify`） | 负责人 |
| --- | --- | --- | --- |
| `01-base.sh` | 用户 / swap / 时区 / tailnet | `tailscale status` 在线；时区正确 | mender |
| `02-onebot.sh` | OneBot 客户端 + 反向 WS | 端口可连；日志有连接建立 | mender |
| `03-dsh.sh` | 平台 + web profile + 热装器 | 面板可达；能装卸一个空插件 | mender |
| `04-memory.sh` | 记忆引擎 + 空库 + cron | 写入一条并检索回来 | mender |
| `05-chat.sh` | 聊天线插件 + 人设/AGENTS 模板 | 发一条消息收到回复 | mender |
| `06-outbox.sh` | 出海通道（限速/幂等） | 测试报告真发到；重复不重发 | mender |
| `07-eyes.sh` | eye-server + PC 桥 | `/health` 通；一条笔记落盘 | mender |
| `08-superagent.sh` | orchestrator + 玩具源 + keeper | 产出 `would_accept`；杀进程被拉起 | mender |
| `09-watchdog.sh` | 看护 + 健康检查 + 报表 | 杀进程 30 秒内被拉起 | mender |
| `10-team.sh` | 信箱桥 + relay + 心跳 | 两会话互通且能互相叫醒 | mender |

## 幂等写法（统一模式）

```bash
#!/usr/bin/env bash
set -euo pipefail
NN=01
log() { printf '[%s] %s\n' "$NN" "$*" >&2; }

DRY=0; VERIFY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --verify)  VERIFY=1 ;;
    --yes)     : ;;
    *) log "unknown arg: $a"; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null || { log "missing: $1"; exit 3; }; }

verify() {
  tailscale status >/dev/null && log "verify ok: tailnet online"
}

if [ "$VERIFY" = 1 ]; then verify; exit 0; fi

if [ -f /etc/zzz-installed ]; then log "SKIP: already installed"; verify; exit 0; fi

[ "$DRY" = 1 ] && { log "would: install base packages"; exit 0; }

# ... 实际安装 ...
log "DONE"
verify
```

## 禁止

- 在脚本里写真实 IP / QQ 号 / token（从 env 读）；
- `curl | sh` 拉未固定版本的脚本；
- 用"看起来成功了"当验收（必须 `--verify` 有输出）；
- 把 secret 写进日志（哪怕 debug 模式）。
