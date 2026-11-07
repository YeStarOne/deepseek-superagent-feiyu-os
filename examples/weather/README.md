# weather —— 最小玩具 Source（observe→auto 全流程）

不依赖真实业务、不需要任何凭据。证明一件事：**一个事件源如何经过闸门变成工单，以及为什么先 observe 后 auto**。

## 三步走

```bash
bash demo.sh --observe   # 3 天天气数据流过五道闸，打印 would_trigger / skip 和原因
bash demo.sh --auto      # 同样的数据，auto 档直接触发（打印模拟工单）
```

跑完你会看到：同一条「暴雨」事件，observe 档只记录「本来会触发」不执行；auto 档直接开工单。

## 接真引擎

`source.template.mjs` 是最小 Source 模板：轮询数据源 → 按规则评估 → 提交 trigger。真实部署时把它挂进你的 superagent 引擎（`register sources`），端点与凭据从 env 读。**接入 API 以你部署的引擎版本为准**——本目录只承诺结构语义与闸门纪律。

## 闸门纪律（这个例子真正想教的）

1. **observe 先行**：新来源先跑 observe，只记录 `would_accept`，不真执行；
2. **对账**：把 observe 记录与人工判断对上，规则收紧到位；
3. **才切 auto**：切闸留痕、可一键回滚（改回 observe 即停手）。

真实代价案例：切闸前 4/4 窗口对账抓出 100% 假阳性——见 `feiyu/docs/03-cases/02-observe-before-auto.md`。
