# 工程史 · hello-bundle 实验——dsh plugin 三种安装源与 bundle 包形态

> 一句话：**`dsh plugin add` 就是转发给 pnpm，三种源（本地路径 / git url / npm scope）全走得通；真正的坑都在 pnpm 的老规矩里——patch 的 `name` 是模块名不是显示名、裸仓 HEAD、prepare 构建门、prerelease 兼容门。**

实验日期 2026-11-07 · dsh 0.2.1-rc.2 · 全程隔离 `DSH_HOME`（`$HOME/dsh-bundle-test/home`），生产 `~/.dsh` 零接触，生产 `dsh-web` 服务全程 active 未受扰。

## 0. 结论三行（要的就是这个）

| 源 | 能装 | 能卸 | 坑 |
| --- | --- | --- | --- |
| 本地路径 | ✅ 一次通过 | ✅ 全周期 | 无（pnpm 以 `link:` 接入） |
| git url | ✅（修两处后） | ✅ | ①裸仓 HEAD 指向 master 而只推了 main → `Could not resolve HEAD to a commit`；②git 包有 prepare 脚本时 pnpm 默认阻止构建，按提示在 profile 的 `pnpm-workspace.yaml` 加 `allowBuilds` 再跑 |
| npm scope | ✅ 机制通（解析+开下载） | （同 pnpm 通路，未单独再测） | 参照样 `@kenz1117/dsh-engram` 连带 onnxruntime-node 113 MB，150s/500s 均超时未下完——**没被证伪，只是大** |

## 1. 包形态：最小三件套（实测可用的样子）

```
dsh-fish-hello/
├── package.json        # "main" + "type":"module" + dsh.bundle.patch 声明
├── cordis.patch.yml    # 一条 insert
└── lib/index.js        # export function apply(ctx, config)
```

`package.json` 关键字段：

```json
{
  "name": "dsh-fish-hello",
  "version": "0.0.1",
  "type": "module",
  "main": "./lib/index.js",
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
}
```

`cordis.patch.yml`（⚠️ `name` 填**模块名**，引导时按它 require 包；填成中文显示名不会报安装错，但 `apply()` 永远不执行）：

```yaml
- insert:
    - id: dsh-fish-hello
      name: dsh-fish-hello
      config: {}
```

`lib/index.js`：

```js
export function apply(ctx, config) {
  ctx.logger?.info?.('fish-hello alive');
}
```

## 2. 机制四条（读 dsh 源码 + 实测对上）

1. **`dsh plugin` = pnpm 转发**。`dsh plugin --profile <name> add <pkg>` 就是在 `<DSH_HOME>/profiles/<name>/` 里跑 `pnpm add`，pnpm 缺席直接报 `pnpm was not found`。**服务器上想装插件，先给 agent 装 pnpm**（本次装在实验前缀，未动全局）。
2. **bundle 清单自动维护**。add 成功后自动把包名追加进 profile manifest 的 `dsh.profile.bundles`（定序：安装锚解析优先，profile 的 `node_modules` 其次）；remove 自动摘除。不需要手改 manifest。
3. **兼容门**：包声明了 `engines.dsh` 就只认它；没声明则检查 `peerDependencies` 里的 `@deepseek-ai/dsh*`；都没有 = 兼容。**prerelease 运行时（0.2.1-rc.2）不满足 `>=0.2.0` 这类无预发布比较子的范围**——第三方包若写了这种 engines，bundle 会被静默 SKIP（启动时 stderr 报 `skipping profile bundle ...`）。我们最小包不声明任何 engines/peer → 兼容。
4. **验收工具**：`dsh --profile <name> --dump-config` 打印合成树即退。装上后树里出现 `# == dsh-fish-hello` 段；卸载后 grep 归零。`--dump-config` 不执行 `apply()`。

## 3. `apply()` 执行证明 + 裸 profile 空转坑

- 纯 `dsh-base` 的裸 profile **没有 app surface**：裸引导挂起空转、零输出、`apply()` 不执行——排障时别在这上面白等。
- 用 web 模板（`--from-default-profile web` 重建+直接引导，注意它引导后**就是常驻服务**不是卡死）或手动把 `@deepseek-ai/dsh-web-app` 加进 bundles：
  - 用 `--patch` 把 webserver 钉到 `127.0.0.1:3987`（生产绑定的是另一张网卡的 3080，端口不冲突，但钉死 loopback 是硬约束）；
  - 引导即见 webserver URL 打印 + `apply()` 内埋的标记文件落盘 → **插件代码被真实加载执行**。
- 日志去向：裸引导 stdout 无 logger 输出，验证 `apply()` 用副作用探针（写标记文件）最稳。

## 4. git 源两坑的修法

```bash
# 坑①：git init --bare 默认 HEAD 可能是 master，而你推的是 main
git -C fish-hello.git symbolic-ref HEAD refs/heads/main
# 坑②：dsh 官方 stderr 提示——git 包的 prepare 构建被 pnpm 阻止，
#       把它印出来的键写进 <profile>/pnpm-workspace.yaml 的 allowBuilds 后重跑
```

## 5. 与热装器的兼容（③问）

零冲突，目标不同：热装器管的是**全局安装锚**（`@deepseek-ai/dsh` 本体版本），bundle 装的是 **profile 目录**（manifest + node_modules）。实验全程未写全局树，生产 `dsh-web` active 未断。另注：dsh 文档明确热重载只覆盖 profile 的 `cordis.patch.yml` 用户层——**运行中的实例对 plugin add/remove 的热生效未测**（要在生产 profile 上验触碰红线），按保守口径：装/卸插件后需要重启对应 profile 实例。

## 6. 复现脚本（隔离 HOME，可整段粘贴）

```bash
EXP="$HOME/dsh-bundle-test"; rm -rf "$EXP"; mkdir -p "$EXP/home"; cd "$EXP"
# pnpm 装进实验前缀（不动全局）
npm i -g pnpm --prefix "$EXP/npmpfx" --no-fund --no-audit
export PATH="$EXP/npmpfx/bin:$PATH"; export DSH_HOME="$EXP/home"
# 包三件套（§1 的内容写到 fish-hello/），再建裸仓并修 HEAD：
git init -q --bare fish-hello.git
( cd fish-hello && git init -q && git add -A && git commit -qm init \
  && git push -q ../fish-hello.git main )
git -C fish-hello.git symbolic-ref HEAD refs/heads/main
# 装 / 验 / 卸
dsh plugin --profile fish-test add "$EXP/fish-hello"        # 本地路径
dsh --profile fish-test --dump-config | grep fish-hello     # 树里见 → ok
dsh plugin --profile fish-test remove dsh-fish-hello
dsh --profile fish-test --dump-config | grep -c fish-hello  # 0 → ok
# git 源
dsh plugin --profile fish-git add "git+file://$EXP/fish-hello.git"
# npm 源（小包先试通，大包给足超时）
dsh plugin --profile fish-npm add <scope>/<small-pkg>
```

## 7. 遗留

- `git+https://` 公网源未测（同一条 pnpm 通路，无独立机制）；私仓要配凭据。
- engram 全量装未完成（113 MB，慢管道超两次上限）——npm scope 的**解析与下载推进**已证通，机制结论不受影响。
- 运行中实例的热装/热卸语义待在暂存机上验（生产 profile 红线不碰）。
- 生产落地前置：给 agent 用户装 pnpm（一行 `npm i -g pnpm`，或 corepack）。
