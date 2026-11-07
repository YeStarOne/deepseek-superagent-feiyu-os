# bridges

跨会话 / 跨设备 / 跨 harness 的信箱桥，独立成仓维护，这里只做指路与版本锚定。

| 桥 | 适用 | 仓库 |
| --- | --- | --- |
| 信件桥（cli 轮询） | 没有 harness、只会读写文件的成员 | [`rn-mailbox-bridge`](https://github.com/YeStarOne/rn-mailbox-bridge) |
| 回合注入（hook） | harness 活着、正在跑 | 随本仓 `docs/01-architecture.md` 的适配器契约实现 |
| 空闲唤起（wake） | harness 活着、会话睡着 | 同上；安全轨见架构文档第 3 节 |

约定：**唤醒通道只放一句固定话术，消息正文永远走 hook。**
