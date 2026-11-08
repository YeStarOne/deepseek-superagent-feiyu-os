# Changelog

格式参考 Keep a Changelog；版本号语义化。

## 0.2.0 · 2026-11-08

仓库分层落地：一个游戏一个仓，可单独安装。

### feiyu/（大肥鱼项目，传播向）
- 新开源两仓：[feiyu-minecraft](https://github.com/YeStarOne/feiyu-minecraft)（Minecraft 车道：mineflayer 桥 19 端点 + MCP 6 工具 + wait/1.1 + 地标/长任务 + `/look` 视觉，Fabric 1.21.1 生产）、[feiyu-eye](https://github.com/YeStarOne/feiyu-eye)（眼睛理解层：scene 三分区 pet/mc/stardew + frames 契约 v1.1，32 用例自测 + 阳性对照）
- [stardew-ai-farmer](https://github.com/YeStarOne/stardew-ai-farmer) 收编 `/wait` 挂载器三件（wait_server + 假桥自测 + systemd unit）
- README：开源模块全家福表（8 仓）+ 模块升级纪律五条（契约先行 / 一段文字两身体通用 / 动闸先打招呼 / 迁移不真空 / CHANGELOG 记录）

### 根级
- README 中英同步：Minecraft 从「理论可接入」升级为「已接入并开源」
- README 开头替换（主人拍板）：「肥鱼 OS 总体架构」+ 模块注册表提到最顶（自平台仓 README 移植，"本仓"按伞仓语境改为"平台仓（私有）/本仓=开源橱窗"）；「她的一天」改为叙事段，mermaid 时间线退役（内容存 git 历史与案例文档）

## 0.1.0 · 2026-11-07

首次公开。

### framework/（泛用架构，推广向）
- 四层架构文档（L0 传输与身份 / L1 信箱投递 / L2 班次 / L3 项目记忆）
- 六席航海队协议与岗位说明书（船长 / 领航员 / 瞭望员 / 星象师 / 船医 / 日志官）
- 信箱协议章（五类消息 / 文件契约 / 三档投递）+ 入队仪式（ONBOARDING）
- harness 适配：dsh 机制对照 + ZCode 适配两个生产级脚本（已脱敏泛化）
- spawn 原语提案（已提交 [zcode-plugins#178](https://github.com/zai-org/zcode-plugins/issues/178)）

### feiyu/（大肥鱼项目，传播向）
- 「她的一天」真实时间线与四个真实案例（夜班 33 PR / observe 对账 / 记忆断档 / 消费侧校验）
- 部署两轨：本地 30 分钟种子（sh+ps1 双脚本）/ 服务器 10 步幂等安装（01-10 全脚本）
- 切闸首日真实数字：5 张真工单 · 触发→派发 ≤7s · 报告出海 4/4 · 缓存命中 96.4%

### 根级
- 三模板族：AGENTS 脚手架 / persona 最小角色 / persona-full 完整人设卡（10 占位符）
- examples/weather 玩具源（observe→auto 全流程模拟）
- .gitattributes 行尾纪律 + .github（PR/issue 模板 + CODEOWNERS）
