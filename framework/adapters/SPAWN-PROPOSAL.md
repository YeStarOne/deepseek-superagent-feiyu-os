# Feature Request：`spawn` 原语——让 harness 能程序化开新会话

> 状态：**已提交官方** —— [zai-org/zcode-plugins#178](https://github.com/zai-org/zcode-plugins/issues/178)（ZCode 主仓 issues/discussions 均关闭，插件市场仓为官方社区入口，标题注明 harness 提案请转交核心组）。
> 动机与一线证据来自我们 7×24 生产运转的多会话团队。

## 一句话

给 CLI 增加「**创建新会话并注入首消息**」的原语，让多会话协作团队可以程序化扩编——不用再手动开。

## 动机（一线证据）

我们跑着一支多会话 AI 团队（六席常驻 + 按项目临时扩编的席位）。扩编的最后一步永远是「开一个新会话」：

- 信箱层（RN 五原语）对新会话**零配置**——会话一起来就自动入网，消息随到随收；
- 卡在最后一步：**会话怎么被程序创建**。目前只能桌面端手动点出来，自动化断在源头。

## 提案 API

```
zcode spawn --name <席位名> --workspace <路径> --prompt-file <首消息.md> \
            [--mode <确认模式>] [--automation <定时表达式>]
```

行为：创建新会话进程 → 注入首消息 → 登记 tasks-index →（若装 RN）自动入网 → 按 `--automation` 挂心跳。

## 与既有能力的衔接

- 唤醒五原语（identity / inject / wake / send / presence）扩成**六个**：`spawn`
- 与 automation 体系复用：spawn 出的会话天然可被 automation 持续唤醒（我们已用直写 tasks-index 验证过「给已有会话挂自动化」的通路）
- 与信箱协议衔接：spawn 的 `--prompt-file` 直接指向「入队仪式」模板（[ONBOARDING.md](../bridges/ONBOARDING.md)），新会话起来即自报家门入编

## 安全边界

- 遵守 workspace 权限与确认模式（`--mode` 不放行越权）
- 席位名冲突拒绝；单 workspace 并发上限可配
- spawn 出的会话与其他会话同等受看护（error/interrupted 可被定向唤醒）

## 我们愿意提供

一线使用案例全文、协议文件（ONBOARDING.md）、实测反馈，以及一个真实的「丢项目进来长出一个部门」场景：游戏主持、mod 开发、后勤席位按需扩编。
