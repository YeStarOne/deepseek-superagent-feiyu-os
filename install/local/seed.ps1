# ---------------------------------------------------------------------------
# 种子（Windows / PowerShell）：本地最快跑通，无服务器、无 QQ 也能装到"脑+记忆"
#
#   powershell -ExecutionPolicy Bypass -File install\local\seed.ps1 -DryRun
#   powershell -ExecutionPolicy Bypass -File install\local\seed.ps1 -Yes
#   ~\.feiyu\bin\start.ps1
#   ~\.feiyu\bin\doctor.ps1
#
# 契约：幂等 / 失败即停 / 配置全走 env / 不打印任何凭据
# ---------------------------------------------------------------------------
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Verify,
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$step = '[seed]'
function Log([string]$m) { Write-Host "$step $m" }

$RepoDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # install\local\ -> 仓库根
if (-not (Test-Path (Join-Path $RepoDir 'env.example'))) { Log "FATAL: 找不到 env.example（请在仓库内运行）"; exit 2 }

$FeiyuHome  = if ($env:FEIYU_HOME) { $env:FEIYU_HOME } else { Join-Path $env:USERPROFILE '.feiyu' }
$DshVersion = if ($env:DSH_VERSION) { $env:DSH_VERSION } else { '0.2.1-rc.2' }
$DshHost    = if ($env:DSH_HOST)    { $env:DSH_HOST }    else { '127.0.0.1' }
$DshPort    = if ($env:DSH_PORT)    { $env:DSH_PORT }    else { '3080' }
$HeapMb     = if ($env:DSH_HEAP_MB) { $env:DSH_HEAP_MB } else { '640' }

function Verify {
  $fail = 0
  try { $v = (node -v); Log "verify ok: node $v" } catch { Log "verify FAIL: node 缺失"; $fail = 1 }
  # M1/M2：exit 0 但零输出/报错的 dsh CLI 是"假绿"（Node 下 import.meta.main 恒 false 的仓库级缺陷）——版本号为空必须 FAIL
  try {
    $d = ((dsh --version 2>$null | Out-String).Trim())
    if ([string]::IsNullOrWhiteSpace($d) -or $d.StartsWith('error')) { throw "dsh 探针异常输出: $d" }
    Log "verify ok: dsh $d"
  } catch { Log "verify FAIL: dsh 不可用或假活（$($_.Exception.Message)）"; $fail = 1 }
  if (Test-Path (Join-Path $FeiyuHome '.env')) { Log "verify ok: .env 就位" } else { Log "verify FAIL: .env 不存在"; $fail = 1 }
  if (Test-Path (Join-Path $FeiyuHome 'memory-data')) { Log "verify ok: memory-data 目录在" } else { $fail = 1 }
  return $fail
}

if ($Verify) { exit (Verify) }

# --- A0 环境预检 --------------------------------------------------------------
Log "A0 环境预检"
foreach ($t in @('git', 'node', 'npm', 'python')) {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { Log "FATAL: 缺少 $t"; exit 3 }
}
# PS5.1 传参会吃掉内嵌双引号，所以不用 node -p，改拆 node -v 的输出
$nodeMajor = [int](((node -v).TrimStart('v')).Split('.')[0])
if ($nodeMajor -lt 20) { Log "FATAL: Node $(node -v) 过旧，需要 >= 20"; exit 3 }

# --- A1 脚手架 + .env ----------------------------------------------------------
Log "A1 脚手架 $FeiyuHome"
foreach ($d in @('bin', 'logs', 'memory-data', 'plugins')) {
  $p = Join-Path $FeiyuHome $d
  if ($DryRun) { Log "would: mkdir $p" } else { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
$envFile = Join-Path $FeiyuHome '.env'
if (Test-Path $envFile) {
  Log "SKIP: .env 已存在（绝不覆盖）"
} elseif ($DryRun) {
  Log "would: 复制 env.example -> $envFile"
} else {
  Copy-Item (Join-Path $RepoDir 'env.example') $envFile
  Log "已生成 $envFile —— 至少填 API_KEY / API_BASE / MODEL_MAIN"
}

# --- A2 平台 -------------------------------------------------------------------
Log "A2 平台 @deepseek-ai/dsh@$DshVersion"
$hasDsh = $false
try { dsh -v 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $hasDsh = $true } } catch {}
if ($hasDsh) {
  # M2 活性探测：dsh CLI 在 Node 22 下可能 exit 0 但零输出/报错（bin.js 的 import.meta.main 守卫是 Deno/Bun 语义）——
  # 这种"假活"会让 dsh web 假装启动、实际什么都没干。检测到就停，别让用户带着死 CLI 往下走。
  $probe = ((dsh --version 2>$null | Out-String).Trim())
  if ([string]::IsNullOrWhiteSpace($probe) -or $probe.StartsWith('error')) {
    Log "FATAL: dsh CLI 假活（exit 0 但零输出/报错）——已知仓库级缺陷：bin.js 入口守卫 if (import.meta.main) 在 Node 下恒 false。"
    Log "  处置：安装 Bun（https://bun.sh）后用 'bun dsh ...' 调用，或向上游确认你的 Node 版本兼容性。"
    exit 4
  }
  Log "SKIP: dsh 已安装且活性正常（$probe）；要换版本：npm i -g @deepseek-ai/dsh@$DshVersion"
} elseif ($DryRun) {
  Log "would: npm i -g @deepseek-ai/dsh@$DshVersion"
} else {
  npm install -g "@deepseek-ai/dsh@$DshVersion"
  if ($LASTEXITCODE -ne 0) { Log "FATAL: npm 安装失败"; exit 4 }
}

# --- A3 起停/体检脚本 ------------------------------------------------------------
if ($DryRun) {
  Log "would: 写入 bin\start.ps1 / stop.ps1 / doctor.ps1"
} else {
  @"
# 前台启动（Ctrl+C 停）。24/7 走服务器路线 B。
# 独立 DSH home：避开共享 ~/.dsh 里旧版本第三方插件的 required-plugin 兼容冲突（整个 home 只属于这条鱼）
`$env:DSH_HOME = Join-Path '$FeiyuHome' 'dsh-home'
`$env:NODE_OPTIONS = "--max-old-space-size=$HeapMb"
dsh web --host $DshHost --port $DshPort --no-open
"@ | Set-Content -Encoding UTF8 (Join-Path $FeiyuHome 'bin\start.ps1')

  @"
# 停本地 dsh web（匹配串兼容 npm-shim / dsh.cmd 包装的进程）
Get-CimInstance Win32_Process -Filter "Name like 'node%'" |
  Where-Object { `$_.CommandLine -match 'dsh web --host|dsh\.cmd|npm-shim' } |
  ForEach-Object { Stop-Process -Id `$_.ProcessId -Force; 'stopped' }
"@ | Set-Content -Encoding UTF8 (Join-Path $FeiyuHome 'bin\stop.ps1')

  @"
# 本地体检（只读不修）
`$ok = 0; `$bad = 0
function Chk(`$name, `$scriptBlock) {
  try { & `$scriptBlock | Out-Null; Write-Host "  OK   `$name"; `$script:ok++ }
  catch { Write-Host "  FAIL `$name（`$(`$_.Exception.Message)）"; `$script:bad++ }
}
Chk 'node >= 20 在位'      { [int](((node -v).TrimStart('v')).Split('.')[0]) -ge 20 }
Chk 'dsh 可用（非假活）'    { `$v = (dsh --version 2>$null | Out-String).Trim(); if ([string]::IsNullOrWhiteSpace(`$v) -or `$v.StartsWith('error')) { throw 'dsh 探针异常（CLI 假活，见 seed 的 M2 提示）' }; `$v }
Chk '.env 就位'            { Test-Path '$envFile' }
Chk 'memory-data 可写'     { `$p = Join-Path '$FeiyuHome' 'memory-data\.probe'; New-Item -ItemType File -Force -Path `$p | Out-Null; Remove-Item `$p }
# 面板配对锁阶段返回 401/403 是正常状态（等待 token 配对），不算 FAIL；用 curl.exe 因为 Invoke-WebRequest 遇 401 会抛异常
Chk '面板可连($DshHost`:$DshPort)' { `$c = (curl.exe -s -o NUL -w "%{http_code}" "http://$DshHost`:$DshPort"); if (`$c -notin @('200','301','302','401','403')) { throw "面板 HTTP `$c" }; `$c }
Write-Host "  —— `$ok 项通过，`$bad 项未过。未过的看 docs/04-deploy.md 对应步骤。"
if (`$bad -gt 0) { exit 1 }
"@ | Set-Content -Encoding UTF8 (Join-Path $FeiyuHome 'bin\doctor.ps1')
}

# --- 收尾 ------------------------------------------------------------------------
if ($DryRun) {
  Log "dry-run 结束，没有改动任何东西。加 -Yes 实装。"
} else {
  Verify | Out-Null
  Log "依赖提示：dsh CLI 需要 Bun 语义的入口（Node 下可能出现 exit 0 零输出的假活，A2 步会帮你检测）；装 Bun 见 https://bun.sh"
  Log "完成。下一步："
  Log "  1) 编辑 $envFile，至少填 API_KEY / API_BASE / MODEL_MAIN"
  Log "  2) powershell -File $FeiyuHome\bin\start.ps1   # 起后开 http://${DshHost}:$DshPort"
  Log "  3) powershell -File $FeiyuHome\bin\doctor.ps1  # 体检"
  Log "  可选加餐（docs/04-deploy.md 路线 A）：A4 superagent / A5 团队网 / A6 QQ 聊天线"
}
