# examples

证明"观察 → 自动"能跑通的最小玩具，不依赖任何真实业务。

## 计划中的示例

| 示例 | 证明什么 | 状态 |
| --- | --- | --- |
| `weather-source` | 一个 Source 能产 Trigger → 过准入闸 → 记录 `would_accept` | ⏳ |
| `ticket-roundtrip` | 工单从 open 到 ready，报告能出海 | ⏳ |
| `two-sessions` | 两个会话互相发信，空闲的能被叫醒 | ⏳ |

## 约束

- 只用公开数据源，不需要任何凭据（或只用免费占位）；
- 不包含真实人设、真实对话、真实地址；
- 每个示例都能 `--dry-run` 跑一遍，不写生产状态。
