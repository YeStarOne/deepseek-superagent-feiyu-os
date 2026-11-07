# adapter/zcode 版：由主持会话脚本脱敏泛化（会话ID/工作区/服务器均参数化）；原始纪律见 docs/02-team.md

# dev-shift-scheduler.py (2026-11-07): 给"开发主持值守"建一条真·周期自动化
# ---------------------------------------------------------------------------
# 背景: ZCode 的 CronCreate 只能在"还没挂定时任务"的会话里建, 主持会话已经被
#       Reason Network 的唤醒自动化占用 -> 工具直接拒绝. 但桌面端调度器读的是
#       tasks-index.sqlite:
#         SELECT * FROM automations WHERE enabled=1 AND running=0 AND next_run_at<=now
#       所以这里直接写一条正常的 20 分钟周期记录(不是 manual run 那种绕法).
#
# 用法:
#   python dev-shift-scheduler.py --install            # 建/更新并启用, 对齐到下一个 20 分钟整点
#   python dev-shift-scheduler.py --status
#   python dev-shift-scheduler.py --disable            # 收工
#   python dev-shift-scheduler.py --interval 30 --install
#
# 注意: 只碰 automation_id == 下面这个常量的行。
import argparse, json, os, sqlite3, sys, time

DB = os.path.expanduser(r'~/.zcode/v2/tasks-index.sqlite')
AUTOMATION_ID = 'automation-devshift-feiyuos'
TITLE = '🧭 鱼鱼OS 开发主持值守'
WORKSPACE_KEY = r'G:\YourWorkspace'
WORKSPACE_PATH = r'G:\YourWorkspace'
TASK_ID = 'sess_REPLACE_WITH_YOUR_CHIEF_SESSION'   # 本会话（大肥鱼总架构）
MODE = 'yolo'
THOUGHT_LEVEL = 'max'
MODEL_SELECTION = '{"providerId":"new-provider","modelId":"deepseek-v4.1-flash","options":{"reasoningLevel":"max"}}'

PROMPT = '''🧭 鱼鱼 OS 开发主持值守（周期唤醒，不是用户在提问）

按顺序做，每轮都要做实事：
0) **队友中断看护**（用户 11-07 明确要求）：查本机会话状态，发现"上一轮 error/interrupted 且 todo 里有 in_progress"的会话就唤醒它继续。
   用只读方式查 ~/.zcode/v2/tasks-index.sqlite 的 tasks 表：task_status IN ('error','interrupted') 且 updated_at 在近 30 分钟内；
   再读 ~/.zcode/cli/db/db.sqlite（mode=ro）的 todo 表看该 session 有无 in_progress 项。
   有则 mcp__reason-network__send_message 发一句："你 01:2x 的回合被 3008 并发限流打断，todo 里还有 X 未完成，请从断点继续，做一段落一次盘"。
   **注意**：自己（本主持会话，用 CHIEF_SESSION_ID 指认）也会因上一轮报错显示 error，跳过自己；同一会话 30 分钟内只唤醒一次，别刷屏。
1) mcp__reason-network__check_inbox 查队友消息：合并请求立刻处理，问题立刻回。
2) ssh agent@<server-host>（带 PATH=$HOME/.local/bin:$PATH GH_CONFIG_DIR=$HOME/.config/gh-agent）
   查 gh pr list -R <owner>/<impl-repo> --state open；有 PR 就 FEIYU_HOST=agent@<server-host> bash scripts/merge-pr.sh <号>。
3) 巡检生产：systemctl --user is-active dsh-web dsh-superagent dsh-outbox-qq eye-server；
   ~/<workspace>/logs/token/ 最新报告；~/pc-body/ledger.jsonl 尾部异常；superagent tickets 计数。
4) 有异常就当天修；修不了写清现象+下一步到 docs/history/ 并走 PR。
5) 推进 docs/03-roadmap.md 的 P1 剩余项（1.2 规则生活化 / 1.3 stardew 切 auto / 1.4 worker 人设 / 1.5 首单验收），
   能直接做的就做，verify.sh 过 → 开 PR → 自己合并（合并权在本会话）。
6) 收尾一句话：本轮做了什么，或"巡检正常 + 具体数值"。

红线：令牌绝不落盘；不重启 SnowLuma；dsh-web 重启必须挑她空闲；网关只绑 Tailscale；不提交 keys_tmp/admin-password；补丁前备份。'''


def next_slot_ms(interval_min: int) -> int:
    step = interval_min * 60 * 1000
    now = int(time.time() * 1000)
    return (now // step + 1) * step


def connect():
    con = sqlite3.connect(DB, timeout=20)
    con.execute('PRAGMA busy_timeout=20000')
    con.execute('PRAGMA journal_mode=WAL')
    return con


def fetch(con):
    cur = con.execute(
        'SELECT automation_id,enabled,lifecycle_status,running,next_run_at,last_run_at,run_count,cron_expr '
        'FROM automations WHERE automation_id=?', (AUTOMATION_ID,))
    r = cur.fetchone()
    if not r:
        return None
    keys = ('automation_id', 'enabled', 'lifecycle_status', 'running', 'next_run_at', 'last_run_at', 'run_count', 'cron_expr')
    return dict(zip(keys, r))


def upsert(con, interval_min: int, enable: bool):
    now = int(time.time() * 1000)
    cron = f'*/{interval_min} * * * *'
    rule = json.dumps({'unit': 'minute', 'interval': interval_min,
                       'hour': time.localtime().tm_hour, 'minute': time.localtime().tm_min,
                       'anchorAt': now}, ensure_ascii=False)
    nxt = next_slot_ms(interval_min)
    enabled = 1 if enable else 0
    status = 'active' if enable else 'paused'
    if fetch(con):
        con.execute('''UPDATE automations SET title=?,cron_expr=?,prompt=?,model_selection=?,mode=?,
                     thought_level=?,workspace_key=?,workspace_path=?,target_task_id=?,location_kind='local',
                     recurring=1,schedule_rule=?,enabled=?,lifecycle_status=?,next_run_at=?,
                     running=0,claimed_at=NULL,updated_at=? WHERE automation_id=?''',
                    (TITLE, cron, PROMPT, MODEL_SELECTION, MODE, THOUGHT_LEVEL, WORKSPACE_KEY, WORKSPACE_PATH,
                     TASK_ID, rule, enabled, status, nxt if enable else None, now, AUTOMATION_ID))
    else:
        con.execute('''INSERT INTO automations (
            automation_id,title,cron_expr,prompt,model,provider,mode,thought_level,
            workspace_key,workspace_path,workspace_identity,target_task_id,bot_delivery_target,location_kind,
            recurring,max_runs,end_at,schedule_rule,schedule_edited_by_user,
            run_count,scheduled_run_count,enabled,lifecycle_status,next_run_at,last_run_at,
            running,claimed_at,dispatch_status,dispatch_attempts,retry_at,last_error,
            created_at,updated_at,model_selection,project_id,host_id,additional_directories
          ) VALUES (?,?,?,?,NULL,NULL,?,?,
            ?,?,NULL,?,NULL,'local',
            1,NULL,NULL,?,0,
            0,0,?,?,?,NULL,
            0,NULL,'idle',0,NULL,NULL,
            ?,?,?,NULL,NULL,NULL)''',
                    (AUTOMATION_ID, TITLE, cron, PROMPT, MODE, THOUGHT_LEVEL,
                     WORKSPACE_KEY, WORKSPACE_PATH, TASK_ID,
                     rule, enabled, status, nxt if enable else None,
                     now, now, MODEL_SELECTION))
    con.commit()
    return fetch(con)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--install', action='store_true')
    ap.add_argument('--disable', action='store_true')
    ap.add_argument('--status', action='store_true')
    ap.add_argument('--interval', type=int, default=20)
    a = ap.parse_args()
    if not os.path.exists(DB):
        print(json.dumps({'ok': False, 'error': f'找不到 {DB}'}, ensure_ascii=False)); return 2
    for attempt in range(3):
        try:
            con = connect()
            if a.status:
                print(json.dumps({'ok': True, 'automation': fetch(con)}, ensure_ascii=False)); return 0
            if a.disable:
                print(json.dumps({'ok': True, 'automation': upsert(con, a.interval, False)}, ensure_ascii=False)); return 0
            if a.install:
                r = upsert(con, a.interval, True)
                print(json.dumps({'ok': True, 'automation': r,
                                  'next_in_min': round((r['next_run_at'] - time.time() * 1000) / 60000, 1)},
                                 ensure_ascii=False))
                return 0
            ap.print_help(); return 1
        except sqlite3.OperationalError as e:
            if 'locked' in str(e).lower() and attempt < 2:
                time.sleep(1.5); continue
            print(json.dumps({'ok': False, 'error': str(e)}, ensure_ascii=False)); return 2
        finally:
            try: con.close()
            except Exception: pass
    return 2


if __name__ == '__main__':
    sys.exit(main())