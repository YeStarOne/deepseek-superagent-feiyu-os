# 04 · 部署：两条路

> **默认走 A：本地。** 不需要服务器、不需要公网 IP，一台普通电脑（Windows / Linux / macOS）就能把"脑 + 记忆 + 事件线"跑起来。
> B 是可选升级：要 24/7 在线、要 QQ 常驻时再上服务器。

## 原则（三条，不可交易）

1. **幂等**：每一步重复执行结果相同；脚本自己判断"已装/未装"。
2. **失败即停**：`set -euo pipefail`；中途失败不带着半截状态往下走。
3. **自带验收**：每一步都要给一条可执行的验收命令。**"看起来成功了"不算。**

## 路线总览

```
A 本地（默认，约 30 分钟）                B 服务器（可选，24/7）
──────────────────────────            ──────────────────────────
A0 环境预检                            01 基础系统
A1 脚手架 + .env                       02 OneBot 客户端 + 登录
A2 平台（npm 包，本地 :3080）           03 平台 + 热装器
A3 记忆引擎 + 空库                     04 记忆引擎 + 蒸馏/备份 cron
   ── 到这里"脑"已经能跑 ──             05 聊天线接线
A4 superagent + 玩具源（可选）          06 出海通道
A5 团队网信箱桥（可选）                 07 眼睛
A6 QQ 聊天线（可选，本地客户端）        08 superagent
A7 doctor 三绿                         09 看门狗
                                       10 团队网
```

A 与 B 不是二选一：本地先跑通，之后把同一套配置搬上服务器（配置全部来自 `.env`，迁移 = 复制目录 + 重跑）。

---

## 路线 A · 本地（默认）

一键种子（在仓库根目录）：

```bash
# Linux / macOS
bash install/local/seed.sh              # 先 --dry-run 看一眼
bash install/local/seed.sh --yes        # 实装
~/.feiyu/bin/start.sh                   # 起（前台，Ctrl+C 停）
~/.feiyu/bin/doctor.sh                  # 体检
```

```powershell
# Windows（PowerShell）
powershell -ExecutionPolicy Bypass -File install\local\seed.ps1 -Yes
~\.feiyu\bin\start.ps1
~\.feiyu\bin\doctor.ps1
```

### A0 · 环境预检
- **要什么**：git、Node ≥ 20、npm、Python ≥ 3.10；空闲内存 ≥ 2 GB。
- **验收**：seed 脚本第一步会逐项打印版本号；缺什么它会说缺什么。

### A1 · 脚手架 + .env
- **做什么**：建 `~/.feiyu/{bin,logs,memory-data,plugins}`；`env.example` 复制为 `.env`（**已存在则不动**，权限 600）。
- **填什么**：最少只需要 `API_KEY` / `API_BASE` / `MODEL_MAIN` 三项；其余全部有安全默认值。
- **验收**：`test -f ~/.feiyu/.env && grep -c API_KEY ~/.feiyu/.env`。

### A2 · 平台（本地端口）
- **做什么**：`npm install -g @deepseek-ai/dsh@<版本>`；生成 `start.sh`（`dsh web --host 127.0.0.1 --port 3080 --no-open`，堆 640 MB）。
- **为什么 127.0.0.1**：本地跑就只听回环，不对局域网开口；要远程访问走 tailnet，不开公网。
- **验收**：`dsh -v` 有输出；起服务后浏览器打开 `http://127.0.0.1:3080`。

### A3 · 记忆引擎 + 空库
- **做什么**：装记忆图谱插件（公开仓）、初始化空库、（可选）每晚蒸馏 cron。
- **验收**：写入一条测试记忆并检索回来；`memory-data/` 出现文件。
- **自检**：看**最近一次成功写入时间戳**——不涨就是断档，哪怕进程活着。

### A4 · superagent + 玩具源（可选）
- **做什么**：起 orchestrator，装 `examples/` 的玩具源，`eval.mode=observe`。
- **验收**：玩具源产出一条 `would_accept` 记录；没有真实业务也能看到"观察"在工作。

### A5 · 团队网信箱桥（可选）
- **做什么**：装 [`feiyuos-mailbox-bridge`](https://github.com/YeStarOne/feiyuos-mailbox-bridge)，加入一个团队（或自建 relay）。
- **验收**：两个会话互相发信并收到；空闲会话约 20–30 秒被叫醒。
- **不想加入团队？** 跳过。单机的"脑 + 记忆 + 工单"不依赖它。

### A6 · QQ 聊天线（可选）
- **做什么**：本地跑一个 OneBot 兼容客户端（NapCat / Lagrange 都行），反向 WS → 平台插件。
- **人工**：扫码登录；掉登录的恢复步骤见 runbook。
- **验收**：发一条消息收到回复；回合中插话也能收到。
- **注意**：文档只教"接入任意 OneBot 客户端"，不绑定实现。

### A7 · 体检
- **验收**：`doctor.sh` 全绿——`node/dsh 版本`、`.env 就位`、`memory-data 可写`、`面板可连`。
- **下一步**：把 `HANDOFF` 写上"装到哪一步、哪一步失败过"。

---

## 路线 B · 服务器（可选，24/7）

适用：要她**全天在线**（QQ 常驻、夜里值守）。一台 1.7 GB 内存的小机器就够全家桶。

| # | 步骤 | 依赖 | 验收 |
| --- | --- | --- | --- |
| 01 | 基础系统（用户 / swap / 时区 / tailnet） | 无 | `tailscale status` 在线 |
| 02 | OneBot 客户端 + 登录 | 01 | 反向 WS 端口可连 |
| 03 | 平台 + web profile + 热装器 | 01 | 面板可达；热装器能装卸插件 |
| 04 | 记忆引擎 + 空库 + 蒸馏/备份 cron | 03 | 写入并检索回一条 |
| 05 | 聊天线接线 + 人设/AGENTS 模板 | 02、03 | 发一条消息得到回复 |
| 06 | 出海通道（限速 ≥8s） | 05 | 测试 DM 真发到；重复不重发 |
| 07 | 眼睛（eye-server + PC 桥 + 桌宠） | 01、03 | `/health` 通；一条笔记落盘 |
| 08 | superagent + 玩具源 + keeper | 03、04 | `would_accept` 有记录；杀进程被拉起 |
| 09 | 看门狗 + health_check + 报表 | 03–08 | 杀进程 30 秒内被拉起 |
| 10 | 团队网（信箱桥 + 心跳） | 08、09 | 两会话互通且互相叫醒 |

配套：`deploy/systemd/*.service.in`、`deploy/cron/crontab.example`、`deploy/cordis.patch.yml.example`。脚本契约见 [`install/README.md`](../../install/README.md)。

**两种占位符，两个消费者，别混**：

| 位置 | 占位符 | 谁展开 | 没填会怎样 |
| --- | --- | --- | --- |
| `.service.in` / `crontab.example` | `@X@` | **安装脚本**（systemd 不认识 `@X@`，是惰性字符串） | 装前断言直接拒绝安装 |
| `docs/` / `env.example` / `cordis.patch.yml.example` | `${X}` | **人**（cordis 的 `${}` 只是待填标记，dsh 不展开） | 看得出来，无害 |

为什么不是全用 `${}`：`.service` 里的 `${X}` 会被 **systemd 运行时展开**（`man systemd.service`：未设则「if any」替换为空），crontab 里的会被 **sh** 展开——没填不报错，服务照常起、只是绑在空地址/空路径上。那正是"看起来成功了"。所以机器消费者一律用惰性 `@X@`，**装前断言**：模板里残留 `@[A-Z_]+@` 就拒绝安装。

**从 A 迁到 B**：`.env` 和 `memory-data/` 打包带走 → 在服务器重跑种子（同一脚本）→ systemd 单元接管进程。配置不落地在仓库里，迁移不丢东西。

---

## 脚本契约（A/B 通用）

```
--dry-run     只打印将要做什么，不改系统
--verify      只跑验收命令，打印真实输出
--yes         非交互
幂等          重复执行结果相同；已完成步骤打印 SKIP
失败即停      set -euo pipefail；非 0 退出
日志          stderr，单行前缀 [步骤号]
配置          一律从 env 读，脚本内不写死地址/路径/凭据
```

## 部署后必须做的三件事

1. `bash scripts/check-secrets.sh`（若已实现）或按 [`docs/06-sanitize.md`](../../docs/06-sanitize.md) 手工过一遍；
2. `doctor` 全绿：**能收信 / 能唤醒 / 能回信**（接了团队网才查后两项）；
3. 写一条 `HANDOFF`：装到第几步、哪一步失败过、怎么验的。
