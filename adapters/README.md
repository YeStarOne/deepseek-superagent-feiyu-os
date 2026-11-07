# adapters —— 会话层适配（harness 可插拔）

> 底座大家基本都用 deepseek harness（dsh）；「会话怎么被唤醒、怎么收消息、怎么被看护」做成可插拔协议，一个 harness 一个实现目录。我们跑通了两套。

| 能力 | dsh 原生（`adapters/dsh/`） | ZCode 适配（`adapters/zcode/`，已生产验证） |
| --- | --- | --- |
| 会话载体 | dsh-web 内 session（`onebot-*`） | ZCode CLI 会话（Reason Network 注册，`yestar/<名>`） |
| 唤醒 | companion-life 60s poll + cron | RN automation / 直写 `tasks-index.sqlite`（见 `dev-shift-scheduler.py`） |
| 收消息 | onebot 插件投递 | Reason Network 信箱（push/turn/pull 三档）+ mailbox-bridge |
| 看护 | health_check + 看门狗 | `teammate-watch.py`：error/interrupted 且 todo 有 in_progress → 定向唤醒 |
| 已知禁区 | — | 单会话定时任务上限 1 条（所以才直写库） |

## adapters/zcode
- `dev-shift-scheduler.py` —— 主持心跳调度器：直写 tasks-index 建/查/停 `*/20 * * * *` 值守任务（模式 yolo、模型/推理档可选）。
- `teammate-watch.py` —— 队友中断看护：只读扫描 error/interrupted 且 todo 有 in_progress 的会话，30 分钟内同一会话只唤醒一次。

两脚本均由生产脚本脱敏泛化：会话 ID / 工作区 / 服务器地址已参数化（`CHIEF_SESSION_ID`、`CHIEF_WORKSPACE`、`<server-host>`）——使用前把占位符换成你自己的值。
