# Changelog

格式参考 Keep a Changelog；版本号语义化。

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
