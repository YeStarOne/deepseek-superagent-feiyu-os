# adapter/zcode 版：由主持会话脚本脱敏泛化（会话ID/工作区/服务器均参数化）；原始纪律见 docs/02-team.md

# teammate-watch.py (2026-11-07): 队友中断看护——找出"上一轮被打断且手头还有未完成项"的会话
# ---------------------------------------------------------------------------
# 背景: GLM Start Plan 池有并发上限, 多会话同时长回合会互相挤掉
#       (provider_code=3008 reason=rate_limited / user concurrency limit exceeded).
#       被打断的会话不会自己恢复, 需要外部唤醒.
#
# 判据（三条同时满足才算"需要唤醒"）:
#   1) tasks-index.sqlite 的 tasks.task_status IN ('error','interrupted')
#   2) tasks.updated_at 在近 N 分钟内（默认 30）
#   3) cli/db/db.sqlite 的 todo 表里该会话有 status='in_progress' 的项
#
# 用法:
#   python -I teammate-watch.py                 # 列出需要唤醒的会话（只读）
#   python -I teammate-watch.py --json          # 机器可读
#   python -I teammate-watch.py --minutes 60    # 放宽时间窗
#
# 只读: 两个 sqlite 都以 mode=ro 打开, 不写任何东西.
import argparse, io, json, os, sqlite3, sys, time

TASKS_DB = os.path.expanduser(r'~/.zcode/v2/tasks-index.sqlite')
CLI_DB = os.path.expanduser(r'~/.zcode/cli/db/db.sqlite')
CHIEF_SESSION_ID = os.environ.get('CHIEF_SESSION_ID', 'sess_REPLACE_WITH_YOUR_CHIEF_SESSION')  # 主持会话自己, 永远跳过

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')


def open_ro(path):
    return sqlite3.connect(f'file:{path}?mode=ro', uri=True, timeout=15)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--minutes', type=int, default=30)
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args()
    now = int(time.time() * 1000)
    cutoff = now - a.minutes * 60 * 1000

    con = open_ro(TASKS_DB)
    con.row_factory = sqlite3.Row
    # 两类可疑：① 上一轮 error/interrupted；② 状态看着正常但"很久没动 + todo 里还有未完成"
    #    （第二种常出现在自动化会话：上一轮 completed 但 todo 卡在 in_progress）
    rows = con.execute(
        "SELECT task_id,title,task_status,updated_at,meta_json FROM tasks "
        "WHERE (task_status IN ('error','interrupted') AND updated_at >= ?) "
        "   OR (task_status IN ('completed','idle') AND updated_at < ? AND updated_at >= ?) "
        "ORDER BY updated_at DESC",
        (cutoff, cutoff, cutoff - 6 * 3600 * 1000)).fetchall()
    con.close()

    out = []
    if not rows:
        print('✅ 无中断会话' if not a.json else '[]')
        return 0

    cli = open_ro(CLI_DB)
    cli.row_factory = sqlite3.Row
    for r in rows:
        tid = r['task_id']
        if tid == CHIEF_SESSION_ID:
            continue
        try:
            todos = cli.execute(
                "SELECT content,status FROM todo WHERE session_id=? AND status='in_progress' ORDER BY position",
                (tid,)).fetchall()
        except sqlite3.OperationalError:
            todos = []
        if not todos:
            continue
        err = ''
        try:
            meta = json.loads(r['meta_json'] or '{}')
            err = ((meta.get('lastError') or {}).get('detail') or '').split('\n')[0][:120]
        except Exception:
            pass
        stalled = r['task_status'] in ('completed', 'idle')
        out.append({
            'session_id': tid, 'title': r['title'], 'status': r['task_status'] + ('（停滞）' if stalled else ''),
            'age_min': round((now - r['updated_at']) / 60000, 1),
            'error': err,
            'in_progress': [t['content'] for t in todos],
        })
    cli.close()

    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return 0
    if not out:
        print('✅ 无"被打断且还有未完成项"的会话')
        return 0
    for o in out:
        print(f"⚠️ {o['title']} ({o['session_id'][:22]}) · {o['age_min']}min 前 · {o['status']}")
        print(f"   {o['error']}")
        for t in o['in_progress']:
            print(f"   [进行中] {t[:80]}")
    return 0


if __name__ == '__main__':
    sys.exit(main())