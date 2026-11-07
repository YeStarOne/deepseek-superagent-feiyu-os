# scripts

> 这些脚本**尚未随首版提供**（P0/P1 实现）。先定契约，避免各写各的。

## `doctor.py`

一条命令体检，只读不修：

```
python scripts/doctor.py
  → 能收信：信箱桥进程在、团队身份可解析、relay 可达
  → 能唤醒：任务库可写、辅助运行存在、无卡死的 running
  → 能回信：发送通道可用、限速配置合理
退出码 0 = 三项全绿；非 0 = 打印失败项与建议命令
```

## `shift-scheduler`

把"周期唤醒总架构"做成可移植的：

```
shift-scheduler --db <任务库> --workspace <目录> --session <会话键> \
                --prompt-file prompts/host-shift.md --interval 20 \
                [--status|--disable]
```

- 只碰自己那条记录（固定 id 前缀），不碰用户已有任务；
- 与宿主调度器共用一份库时，必须处理 `running` 单飞；
- 唤醒失败要能回退到备用模型线。

## `check-secrets.sh`

```
bash scripts/check-secrets.sh [路径]
  → 密钥模式（token/key/password/…=值）
  → QQ 号段、内网/公网 IP 段、家目录模式
  → 0 命中退出 0；任何命中退出 1 并打印文件:行
```

## `merge-pr.sh`

```
bash scripts/merge-pr.sh <pr-number>
  → 校验：CI 绿、有审核、无冲突、文件范围符合 CODEOWNERS
  → squash merge + 删除分支
  → 失败不改动任何东西
```

## 共同要求

- 只读脚本不改系统；写操作必须 `--dry-run` 可用；
- 输出可被下一个人直接贴进 HANDOFF；
- 不打印任何凭据（哪怕 debug）。
