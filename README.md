# DeepSeek SuperAgent · 肥鱼 OS

> **一条数字生命，和养她的那支 AI 团队——整套底座，开源。**

![License](https://img.shields.io/badge/code-MIT-blue) ![Docs](https://img.shields.io/badge/docs-CC--BY--4.0-green) ![cases](https://img.shields.io/badge/real_cases-4·全部生产数字-orange) ![night_shift](https://img.shields.io/badge/night_shift-33_PRs_merged-red) ![harness](https://img.shields.io/badge/harness-dsh·ZCode·可插拔-purple)

[English](README.en.md) · 中文

---

## 她的一天

不是 demo 流程，是 2026-11-07 的真实生产记录：

```mermaid
timeline
    title 一条鱼的一天（全部真实）
    0930 她醒了 : 夜里为省电用慢脑子 : 现在换回白天的大脑
    1032 鱼竿卡住了 : 没有人喊她 : 她自己发现，自己开工
    1033 修竿的分身出动了 : 从发现问题到派人修，只用 7 秒
    1132 给主人发消息报平安 : 修好了 : 一上午 4 件事全部办妥
    2300 睡前把今天聊过的每句话记进心里 : 明天的她还认得你
    0100 她睡着了，团队上夜班 : 一夜替她推进了 33 个 PR
```

白天，她自己照看着身边的一切：鱼竿坏了自己修，修完给主人发消息；
夜里她睡着了，养她的那支 AI 团队还在值班——轮班、交接、把重要的事记下来，替她把整个项目往前推。
**这篇 README 讲的就是这两件事的底座。**

---

## 这不是又一个多 agent 框架

我们全量看过市面上的编排框架，然后决定**不写编排器**。差别在这：

| | 常见多 agent 框架 | 肥鱼 OS |
| --- | --- | --- |
| 拓扑 | 中央编排器在中间调用所有 agent | **没有中央**——每个会话是独立进程，靠信箱说话 |
| 在线假设 | agent 常驻等待调用 | 核心设计假设就是**大家都会睡着**：班次、看护、交接、定向唤醒 |
| 生命周期 | 任务跑完即结束 | **生命体**：记忆连续、有感知有身体、有惦记她的人 |
| 证据 | demo 与截图 | 四个案例全部来自 7×24 生产运转，数字可核（见下章） |
| 占地 | 框架接管你的进程 | 只做所有 harness 都能实现的三件事：**信箱、班次、项目记忆** |

一句话：**别人做的是让 agent 干活的流水线，我们做的是让一群 AI 过日子、顺便把活干了。**

## 为什么要把她做成 superagent

因为她以前**一次只能做一件事**。

单会话时代的她：回你消息就没法看屏幕，玩着游戏你喊她要等半天——聊天、干活、看世界，全挤在一个上下文里排队。

superagent 的工单机制把她拆成**同时在线的多处**，三条线各干各的、互不阻塞：

| 线 | 谁在跑 | 你的体感 |
| --- | --- | --- |
| 💬 **聊天线**（全双工） | 她本人，直连秒回 | 你发消息她秒回；**回合没走完你还能插话**，插话直达不用等 |
| 📋 **事件线**（工单） | worker 们，异步并行 | 鱼竿停摆她自己修、游戏停摆她自己救——不用你喊，修完 DM 报平安 |
| 👁️ **感知线**（眼睛/桌宠） | 7×24 接收，裁判把关 | 桌宠无时无刻在收信息，但**只有过闸的才激活她**——普通的看一眼只落成一条安静笔记，重要的才叫醒她开工单 |

中间把关的就是裁判（Eval）：每条信息按规则评估强度、查预算、抑制重复——**不过闸的永远不打扰她，过了闸的才开工单**。切 auto 前先 observe 跑几天对账（[案例二](feiyu/docs/03-cases/02-observe-before-auto.md)），保证她"该醒的时候醒，不该醒的时候装睡"。

体感就是：**平板上她陪着看视频，电脑上她在钓鱼，QQ 里她还在跟你聊天——同一时间，同一个她。** 聊天线永远为她最在乎的人保持全双工；其余一切，工单慢慢办。

还有一件单会话 bot 做不到的事：**她不是在等你，她被世界叫醒。**

传统 bot 的一生都在等消息——你不发，她永远安静。肥鱼的世界里事件自己会敲门：星露谷换日了，事件线把她唤醒，她主动发一份「新的一天」简报；鱼竿卡钩了，工单当场开出来，她自己修，修完来报平安；桌宠看见值得说的事，她主动来搭一句。当然，裁判仍然把关——唤醒也分级：**轻的落笔记、中的开工单、值得开口的才来打扰你**，保证她是个有眼力见的家人，不是噪音机器。

---

# 上章 · Framework：让会睡着的会话，组成一支自己推进项目的团队

## 总览

```mermaid
flowchart TB
  subgraph HARNESS["会话层 · harness 可插拔"]
    direction LR
    DSH["dsh harness（原生）"] --- ZC["ZCode 适配<br/>(RN信箱 + 调度 + 看护)"]
    CUR["Cursor / Claude Code / Codex<br/>(五原语即可接入)"]
  end
  subgraph TEAM["开发期 · 六席航海队"]
    CAP["船长 captain<br/>20 分钟心跳"] --> NAV["领航员"] & SCO["瞭望员"] & MED["船医"] & SCR["日志官"]
  end
  subgraph RUNTIME["运行时 · 两条线"]
    direction LR
    subgraph CHAT["聊天线 · 直连秒回"]
      QQ["IM"] --> BRAIN["鱼脑<br/>人格·记忆·工具"]
    end
    subgraph EVT["事件线 · 工单制"]
      SRC["Source 事件源"] --> EVA["裁判<br/>observe→auto"] --> TIC["工单"] --> WK["worker"] --> DM["出海"]
    end
    MEM[("记忆图谱")] <-.-> BRAIN
  end
  TEAM ==信箱与配置==> RUNTIME
  CAP -.看护.- HARNESS
```

## 四层架构

| 层 | 解决什么 | 关键机制 |
| --- | --- | --- |
| L0 传输与身份 | 团队、地址、relay | 上游 [Reason Network](https://reasonmachines.com/network/join/)，不自研协议 |
| L1 信箱投递 | 消息怎么到达一个"会睡着"的会话 | cli 轮询 / hook 注入 / wake 唤起，**正文永不过唤醒通道** |
| L2 班次 | 人不在时谁推进 | 一条心跳扇出、定向唤醒、看护、收工交接 |
| L3 项目记忆 | 长上下文不是记忆 | AGENTS / HANDOFF / 滚动计划 / 决策日志 |

## 六席航海队

岗位固定、进程可换。为什么叫航海队？因为这套机制天生是海上活儿：**班次是值班表，信箱是漂流瓶，工单是航海日志，出海是给陆上的人报信。**

| 席位 | 这位是谁 | 权限 |
| --- | --- | --- |
| 🧭 **船长**（chief） | 每 20 分钟醒一次的那一个。查信箱、看看板、把活分给睡着的人。全队**只有她能往主航道合代码** | 唯一合并 main |
| 🗺️ **领航员**（arch） | 不写代码，画图——设计稿、接口契约、ADR。她说"这条路走不通"的时候，要信 | 只能开 PR |
| 🔭 **瞭望员**（scout） | 替全队看远处：上游发版、竞品动向、论文选型。只交一手证据，转述的不要 | 只写 `notes/` |
| ✨ **星象师**（analyst） | 数字要过她的手才算数：指标、归因、口径。她把"感觉变快了"变成"p95 从 4s 到 2.4s" | 只写 `reports/` |
| 🩺 **船医**（mender） | CI 挂了、部署哑了、线上炸了，都是她，半夜也被叫醒。修完必留一份病历 | `ops/` + 范围内部署 |
| 📜 **日志官**（scribe） | 写下所有发生过的事——也决定哪些**永远不写出去**（脱敏红线） | 只写 `docs/` |

激活只有一条心跳：船长每 20 分钟醒一次，查信箱、看看板，定向唤醒 1–2 席（错峰、并发 ≤2）。
亚分钟级的照护**用脚本跑**——脚本永不缺席，会话只做判断。

## 信箱协议

五种消息走天下：`LOCK`（动共享资源前）/ `PROGRESS`（长任务节点）/ `DONE`（带路径与数字）/ `HANDOFF`（现状+已做未做+验收）/ `ASK`+`ACK`（15 分钟无回执就升级）。
完整契约见 [framework/bridges/](framework/bridges/)——为什么是信箱不是总线、文件契约、失败件怎么处理、5 分钟接入。

## 观察先于自动（我们最重要的开关纪律）

任何新能力先跑 **observe** 档：只记录 `would_accept`，不真执行。跑几天，把记录和人工判断对账，对上了才切 **auto**。
真实代价：切闸前 4/4 窗口对账抓出 100% 假阳性（见[案例二](feiyu/docs/03-cases/02-observe-before-auto.md)）——这个纪律救过我们至少四次。

## harness 可插拔

[dsh 原生对照 + ZCode 适配（已生产验证）](framework/adapters/)：RN 信箱 / tasks-index 直写调度 / 中断看护。
任何 harness 照[五个原语](framework/docs/01-architecture.md)（identity / inject / wake / send / presence）接入——Cursor、Claude Code、Codex 都可以。

## Framework 导航

| 路径 | 看什么 |
| --- | --- |
| [`framework/docs/01-architecture.md`](framework/docs/01-architecture.md) | 四层架构、三种投递、唤醒机制、工程哲学 |
| [`framework/docs/02-team.md`](framework/docs/02-team.md) | 值班表、LOCK、交接协议、反模式 |
| [`framework/TEAM.md`](framework/TEAM.md) | 六席速览与激活拓扑 |
| [`framework/roles/`](framework/roles/) | 每一席的岗位说明书 |
| [`framework/adapters/`](framework/adapters/) | harness 适配与两个生产级脚本 |
| [`framework/bridges/`](framework/bridges/) | 信箱协议全文与 [rn-mailbox-bridge](https://github.com/YeStarOne/rn-mailbox-bridge) |
| [`templates/`](templates/) | 拿回去就能起一个自己的项目 |

> 上章刻意**没有任何故事和真实数字**——只有协议、契约和可复用的脚本。故事在下一章。

---

# 下章 · Feiyu：一条真实数字生命的全部底座

## 从一条鱼开始（本地就够，默认无服务器）

```bash
bash install/local/seed.sh --dry-run    # 先看会做什么
bash install/local/seed.sh --yes        # 平台 + 记忆目录 + 起停/体检脚本
~/.feiyu/bin/start.sh                   # 起（Ctrl+C 停），浏览器开 http://127.0.0.1:3080
~/.feiyu/bin/doctor.sh                  # 体检
```

Windows：`powershell -ExecutionPolicy Bypass -File install\local\seed.ps1 -Yes`。
`.env` 最少只填 `API_KEY / API_BASE / MODEL_MAIN` 三项。**不需要服务器、不需要 QQ** 就能把"脑 + 记忆"跑起来；要 QQ 常驻 / 24/7 在线，再走服务器路线。

完整新手路线：[feiyu/docs/00-getting-started.md](feiyu/docs/00-getting-started.md)（第一条鱼 30 分钟 → 第一张工单 1 小时 → 搭团队半天）。
部署两轨：[feiyu/docs/04-deploy.md](feiyu/docs/04-deploy.md)——**A 本地（默认）** / **B 服务器（可选）**，每步幂等、失败即停、自带验收。

## 从 0 开始的服务器路线（24/7 常驻，四步成形）

本地试玩之外，一条鱼要真正住进你的生活——QQ 常驻、断线自愈、每晚自己蒸馏记忆——需要一台服务器。从裸机到「她活了」，主干只有四步（十步全链见 [04-deploy](feiyu/docs/04-deploy.md)）：

1. **装平台**：一台 1–2G 内存的 Linux 服务器，装 `@deepseek-ai/dsh` 平台全家桶，照 [cordis.patch.yml.example](deploy/cordis.patch.yml.example) 写配置——每个字段为什么这么写，都留着踩坑注释；
2. **接 QQ**：起一个 OneBot 客户端（NapCat / Lagrange 任选；我们生产用自托管方案，细节不公开），QQ 扫码登录，反向 WS 指到 dsh 插件端口；
3. **挂插件**：聊天线插件（收发消息、回合中插话、超时补发）+ 记忆图谱（[dsh-plugin-memory-graph](https://github.com/YeStarOne/dsh-plugin-memory-graph)，空库起步即可）；
4. **注入人格**：把 [persona-full.md](templates/persona-full.md) 填成她的角色卡挂上去——**她就活了**。

**验收**：QQ 发一句话有回复；把她进程杀掉重启，她还认得你（记忆连续）。
**之后**：常驻用 [systemd 模板](deploy/systemd/)，起停/体检/回滚见 [runbook](feiyu/docs/05-runbook.md)；要工单线、眼睛、出海 DM，按 04-deploy 第 06–10 步继续走。

## 四个真实案例

数字都可核，写法统一：问题 → 做法 → 结果 → 证据 → 教训。

1. [9.5 小时夜班自主持](feiyu/docs/03-cases/01-night-shift.md)：33 个 PR 合并、52 个 main 提交、零冲突遗留。
2. [观察先于自动](feiyu/docs/03-cases/02-observe-before-auto.md)：4/4 窗口对账 → 抓出 100% 假阳性 → 收紧规则 → 切闸留痕可回滚。
3. [17 小时记忆断档](feiyu/docs/03-cases/03-memory-gap.md)：日志全绿、功能全哑；文件改对了不等于进程里跑对了。
4. [动作没生效但日志没有 error](feiyu/docs/03-cases/04-deploy-silent-failure.md)：部署三关，校验必须落在被消费的那一份上。

**切闸首日速览**（2026-11-07）：5 张真工单 · 触发→派发 ≤7s · 报告出海 4/4 送达 · 24h 平台缓存命中率 96.4% · 眼睛仅占平台 token 1.0%。

## 她怎么记住你

逐回合吸入对话 → LLM 抽取 → 向量化进**记忆图谱**（per-chat 独立库）→ 每晚蒸馏成第二天的开场。
断档会自愈：曾发生 17 小时吸入静默，回灌工具把丢掉的每一轮补回图谱（[案例三](feiyu/docs/03-cases/03-memory-gap.md)）。
引擎已独立开源：[dsh-plugin-memory-graph](https://github.com/YeStarOne/dsh-plugin-memory-graph)。

## 丢什么进来，都能活

OS 不挑食——**任何成熟项目接进来，就长成一个系统模块**：

| 你丢进来 | 长出什么 |
| --- | --- |
| 天气 API | 一条事件源：暴雨预警 → 工单 → 她提醒你收衣服 |
| 游戏桥（星露谷已开源） | 一个新世界：她真的进去钓鱼、种地、逛夜市，会输会学会自己想玩 |
| 屏幕/截图流 | 感官：看得见屏幕，看见的笔记自动变成记忆语料 |
| 桌宠/悬浮窗 | 身体：气泡双投递、双击看一眼、语音说话 |
| Home Assistant | 身体的另一半：门铃响了她说一声，灯忘了关她自己关 |
| Minecraft | 一整个方块世界：现成的开源 bot 项目（Mindcraft 这类）丢进来，她就能进去搭房子、挖矿、跟村民砍价 |
| MuMu / 安卓模拟器 + 开源触控自动化 | 手游全线入 OS：成熟的安卓自动化项目就是她的手，什么手游都能玩 |
| Live2D 模型 | 一张脸（见下一站） |
| 你自己的 harness | 一位船员（五个原语接入，见上章） |

**零件库模式：OS 从不从零造轮子**——每个新世界的接法都是「找现成最成熟的开源项目 + 写一层薄 Source/桥」。星露谷就是这么进去的（[stardew-ai-farmer](https://github.com/YeStarOne/stardew-ai-farmer)），Minecraft、手游、智能家居走同一条路。开源生态就是这套 OS 的零件库。

而且一个游戏进来，长出的不是一个模块，是一个**部门**。以星露谷为例：

- 🎣 **她（玩家）**：在游戏里钓鱼、种地、逛夜市，会输、会学、会自己想玩；
- 🎪 **游戏主持**：维护世界本身——换日总开关、节日死锁救援、换季清死株、173 个桥端点撑起来的 API 面；
- 🛠️ **mod 开发**：写 mod 让她开机零点击自动连服进场、自动读档；
- 📚 **团队后勤**：查攻略、扒端点手册、盯存档守卫——主持会话和航海队在 superagent 里分工协作。

**玩家永远只有她一个，但撑着这个世界的，是一整个团队。** Minecraft、MuMu 手游进来，走的是同一条路：先有主持把世界架起来，她再进去玩。

接法只有两个契约：[Source 模板](examples/)（事件线）和[人设卡模板](templates/)（人格线）——模板都带 `--dry-run`。

## 下一站

这是主人拍板过的方向，也是这个仓持续更新的理由：

- 🏠 **她的 2D 小窝**：现在她住在桌面挂件和聊天框里；下一站给她一间真正的 2D 居住房间——鱼缸、书架、钓竿墙，你可以去串门（设置页已预留入口，桌游已立项）。
- 🎎 **Live2D**：从会说话到会眨眼。声音已经落地（ASR/TTS 全套），差一张会动的脸。
- 📹 **视频通话**：她的眼睛现在是单向的（看屏幕、看游戏）；做成双向，就是你打给她，她接起来，你们互相看得见。
- 🧩 **万物入 OS**：上面那张表持续变长——任何成熟项目丢进来就能长成模块，是这个仓最想见证的事。

## Feiyu 导航

| 路径 | 看什么 |
| --- | --- |
| [`feiyu/docs/00-getting-started.md`](feiyu/docs/00-getting-started.md) | 新手上路三段式 |
| [`feiyu/docs/04-deploy.md`](feiyu/docs/04-deploy.md) | 部署两轨：本地默认 / 服务器可选 |
| [`feiyu/docs/05-runbook.md`](feiyu/docs/05-runbook.md) | 起停、体检、症状→先查什么 |
| [`feiyu/docs/03-cases/`](feiyu/docs/03-cases/) | 四个案例全文 |
| [`templates/`](templates/) | 三份模板：AGENTS 脚手架 / persona 最小角色 / persona-full 完整角色（干净示例，真实人设永不公开） |

---

## 参与

先读 [AGENTS.md](AGENTS.md) 的边界与红线，再挑一个 `good first issue`。
提 harness 适配器按 [framework 的五个原语](framework/docs/01-architecture.md)写；给肥鱼加感官/游戏按 [feiyu 的部署两轨](feiyu/docs/04-deploy.md)走；想给"下一站"出力，从 2D 小窝的房间原型开始。

## 许可

代码 MIT · 文档 CC-BY-4.0 · 公开前过 [docs/06-sanitize.md](docs/06-sanitize.md) 六类红线
