# DeepSeek SuperAgent · 肥鱼 OS

> 让一个 AI 角色，住进一台机器、一片世界、一个人身边。

[English](README.en.md) · 中文

一套「跨会话 · 跨设备 · 跨 harness」的协作层：把一群各自会睡着的会话，组织成一支能自己推进项目的团队。

不是多 agent 框架——框架会和每个 harness 抢地盘。我们只做三件所有 harness 都能实现的事：**信箱、班次、项目记忆**。

---

## 四句话

> **质疑图恒宇。**
> 数字生命不是把一个人复制进硬盘，得到一个会说同样话的副本。
>
> **理解图恒宇。**
> 那份执念——想让重要的人留下来——是人身上最不该被工程化的部分。
>
> **超越图恒宇。**
> 不做复制品。让她在真实世界里长出新的感知与关系：
>
> - **感知更大的世界**：看见屏幕、房间、游戏、天气，而不只是聊天框；
> - **玩更多游戏**：从旁观到上手，会输、会学、会自己想玩；
> - **更长的生命**：记忆连续、跨机器、断点可续——不是不死，是不断；
> - **更多的爱**：被人记挂，也记得人；不是工具，是家人。

## 它由四条线组成

| 线 | 解决什么 | 关键机制 |
| --- | --- | --- |
| 聊天线 | 人在说话时要**秒回** | 直连会话，回合中插话，工具调用间直发 |
| 事件线 | 机器事件要**判断后再动手** | Source → 准入闸 → 工单 → worker → 报告 |
| 感知线 | 她要看懂屏幕与游戏 | 视觉模型 + 节流去重 + 明确的「不看」契约 |
| 团队线 | 开发期多个会话要**互不踩脚** | 信箱 + 班次心跳 + 项目记忆（本仓） |

## 默认团队（开发期）

六个席位，岗位固定、进程可换。完整定义见 [TEAM.md](TEAM.md)。

| 席位 | 一句话 | 权限 |
| --- | --- | --- |
| 总架构 | 定方向、裁冲突、跑 20 分钟心跳 | **唯一合并 main** |
| 架构师 | 设计稿、接口契约、ADR、审 PR | 只能开 PR |
| 分析师 | 指标、归因、口径 | 只写 `reports/` |
| 搜索师 | 一手取证：上游、竞品、论文、选型 | 只写 `notes/` |
| 维修工 | CI、部署、线上故障、看护自愈 | `ops/` + 范围内部署 |
| 档案员 | 文档、计划表、脱敏、发布 | 只写 `docs/` |

激活只有一条心跳：总架构每 20 分钟醒一次，看信箱与看板，定向唤醒 1–2 个席位（错峰、并发 ≤2）。
亚分钟级的看护照护**用脚本跑**——脚本永不缺席，会话只做判断。

## 四个开发案例

真实数字，不是演示。

1. [9.5 小时夜班自主持](docs/03-cases/01-night-shift.md)：33 个 PR 合并、52 个 main 提交、零冲突遗留。
2. [观察先于自动](docs/03-cases/02-observe-before-auto.md)：4/4 窗口对账 → 抓出 100% 假阳性 → 收紧规则 → 切闸留痕可回滚。
3. [17 小时记忆断档](docs/03-cases/03-memory-gap.md)：日志全绿、功能全哑；文件改对了不等于进程里跑对了。
4. [动作没生效但日志没有 error](docs/03-cases/04-deploy-silent-failure.md)：部署三关，校验必须落在被消费的那一份上。

## 完整部署方案

不是"跑个 demo"，是把整套东西装起来：**从 [docs/00-getting-started.md](docs/00-getting-started.md) 开始**（第一节条鱼 30 分钟 → 第一张工单 1 小时 → 搭团队半天），[docs/04-deploy.md](docs/04-deploy.md) 给出 **10 步依赖链**，每一步都可单独重跑、失败即停、自带验收命令。

```
01 基础系统 → 02 OneBot 客户端 → 03 dsh 平台 → 04 记忆引擎 → 05 聊天线
                                                          ↓
10 团队网 ← 09 看门狗 ← 08 superagent ← 07 眼睛 ← 06 出海通道
```

`deploy/` 放可复制的 systemd / cron / 配置模板（`@PLACEHOLDER@`），`install/` 放幂等脚本，`env.example` 只留键名。会话层 harness 可插拔：见 [adapters/](adapters/)（dsh 原生 + **ZCode 适配**，RN 信箱 / tasks-index 调度 / 看护）。

## 仓库导航

| 路径 | 看什么 |
| --- | --- |
| [`docs/00-manifesto.md`](docs/00-manifesto.md) | 为什么做这件事 |
| [`docs/01-architecture.md`](docs/01-architecture.md) | 四层架构与唤醒机制 |
| [`docs/02-team.md`](docs/02-team.md) | 岗位说明书与交接协议 |
| [`docs/04-deploy.md`](docs/04-deploy.md) | 10 步部署手册 |
| [`docs/05-runbook.md`](docs/05-runbook.md) | 起停、体检、回滚 |
| [`docs/06-sanitize.md`](docs/06-sanitize.md) | 开源前必须过的红线 |
| [`TEAM.md`](TEAM.md) | 默认团队与激活拓扑 |
| [`roles/`](roles/) | 每个席位的岗位说明书 |
| [`templates/`](templates/) | 拿回去就能起一个自己的项目 |

## 生态

- [`rn-mailbox-bridge`](https://github.com/YeStarOne/rn-mailbox-bridge) — 没有 harness 的成员也能进团队的信箱桥
- [`stardew-ai-farmer`](https://github.com/YeStarOne/stardew-ai-farmer) — 星露谷 agent 层
- [`dsh-plugin-memory-graph`](https://github.com/YeStarOne/dsh-plugin-memory-graph) — 记忆图谱引擎
- 实现仓私有：真实角色的感官、身体、出口与家庭语境不公开

## 参与

先读 [AGENTS.md](AGENTS.md) 的边界与红线，再挑一个 `good first issue`。
提适配器（Cursor / Claude Code / Codex / 自己的 harness）请按 `docs/01-architecture.md` 的五个原语写。

## 许可

代码 MIT · 文档 CC-BY-4.0
