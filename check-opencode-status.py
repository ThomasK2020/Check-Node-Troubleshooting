#!/usr/bin/env python3
# ==============================================================================
# Check-Node-Troubleshooting — OpenCode Task Execution & Log Monitor
# ==============================================================================
# Visualizes OpenCode status, active processes launched by Hermes Agent,
# SQLite session data, and real-time activity logs.
# ==============================================================================

import os
import sys
import time
import json
import sqlite3
import argparse
import psutil

LOG_FILE = os.path.expanduser("~/.local/share/opencode/log/opencode.log")
DB_FILE = os.path.expanduser("~/.local/share/opencode/opencode.db")

def get_active_opencode_processes():
    active_procs = []
    my_pid = os.getpid()
    for p in psutil.process_iter(['pid', 'ppid', 'name', 'cmdline', 'create_time', 'cwd', 'cpu_percent', 'memory_info']):
        try:
            if p.info['pid'] == my_pid:
                continue
            cmdline = p.info['cmdline']
            if not cmdline:
                continue
            cmd_str = " ".join(cmdline)
            if 'opencode' in cmdline[0] or (len(cmdline) > 1 and 'opencode' in cmdline[1]):
                if 'lemonade-opencode-proxy' in cmd_str or 'check-opencode' in cmd_str:
                    continue
                
                active_procs.append({
                    'pid': p.info['pid'],
                    'ppid': p.info['ppid'],
                    'cmd': cmd_str,
                    'cwd': p.info.get('cwd', 'N/A'),
                    'create_time': time.strftime('%H:%M:%S', time.localtime(p.info['create_time'])),
                    'elapsed_s': int(time.time() - p.info['create_time']),
                    'cpu': p.info['cpu_percent'],
                    'rss_mb': round(p.info['memory_info'].rss / (1024 * 1024), 1) if p.info.get('memory_info') else 0
                })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return active_procs

def get_latest_session_from_db():
    if not os.path.exists(DB_FILE):
        return None
    try:
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        c.execute('SELECT id, directory, title, time_created, time_updated FROM session ORDER BY time_updated DESC LIMIT 1')
        row = c.fetchone()
        if not row:
            conn.close()
            return None
        sid, directory, title, created_ms, updated_ms = row
        
        prompt = "N/A"
        c.execute('SELECT data FROM part WHERE session_id=? ORDER BY time_created ASC LIMIT 1', (sid,))
        part_row = c.fetchone()
        if part_row:
            try:
                pdata = json.loads(part_row[0])
                if pdata.get('type') == 'text':
                    prompt = pdata.get('text', 'N/A')
            except Exception:
                pass
                
        conn.close()
        return {
            'id': sid,
            'directory': directory,
            'title': title,
            'created_str': time.strftime('%H:%M:%S', time.localtime(created_ms / 1000)),
            'updated_str': time.strftime('%H:%M:%S', time.localtime(updated_ms / 1000)),
            'prompt': prompt
        }
    except Exception as e:
        return {'error': str(e)}

def get_recent_log_entries(num_lines=15):
    if not os.path.exists(LOG_FILE):
        return []
    try:
        with open(LOG_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
            return [l.strip() for l in lines[-num_lines:]]
    except Exception as e:
        return [f"Error reading log file: {e}"]

def get_status_data(num_logs=12):
    procs = get_active_opencode_processes()
    db_session = get_latest_session_from_db()
    logs = get_recent_log_entries(num_logs)
    log_mtime = time.strftime('%H:%M:%S', time.localtime(os.path.getmtime(LOG_FILE))) if os.path.exists(LOG_FILE) else "N/A"
    
    status = "ACTIVE" if procs else "IDLE"
    return {
        'status': status,
        'processes': procs,
        'latest_session': db_session,
        'log_mtime': log_mtime,
        'recent_logs': logs
    }

def print_status(num_logs=12):
    data = get_status_data(num_logs)
    procs = data['processes']
    db_session = data['latest_session']
    logs = data['recent_logs']
    log_mtime = data['log_mtime']
    
    print("\033[1;36m=====================================================\033[0m")
    print("\033[1;36m      OPENCODE TASK EXECUTION & LOG MONITOR          \033[0m")
    print("\033[1;36m=====================================================\033[0m")
    
    if procs:
        print(f"\033[1;32mSTATUS: 🟢 ACTIVE RUNNING TASK ({len(procs)} process)\033[0m\n")
        for p in procs:
            print(f"  • \033[1mPID:\033[0m {p['pid']} (PPID: {p['ppid']})")
            print(f"    \033[1mStarted:\033[0m {p['create_time']} ({p['elapsed_s']}s ago)")
            print(f"    \033[1mWorking Dir:\033[0m {p['cwd']}")
            print(f"    \033[1mResources:\033[0m CPU {p['cpu']}% | RAM {p['rss_mb']} MB")
            print(f"    \033[1mCommand:\033[0m {p['cmd']}")
            print()
    else:
        print("\033[1;33mSTATUS: ⚪ IDLE / NO ACTIVE EXECUTION PROCESS\033[0m\n")

    print("\033[1;34m--- LATEST OPENCODE SESSION (SQLite) ---\033[0m")
    if db_session and 'id' in db_session:
        print(f"  • \033[1mSession ID:\033[0m {db_session['id']}")
        print(f"  • \033[1mDirectory:\033[0m  {db_session['directory']}")
        print(f"  • \033[1mCreated:\033[0m    {db_session['created_str']} | \033[1mLast Updated:\033[0m {db_session['updated_str']}")
        prompt_display = db_session['prompt']
        if len(prompt_display) > 200:
            prompt_display = prompt_display[:200] + "..."
        print(f"  • \033[1mTask Prompt:\033[0m {prompt_display}")
    else:
        print("  No session history found.")
    print()

    print(f"\033[1;34m--- RECENT LOG ACTIVITY (opencode.log - Last modified: {log_mtime}) ---\033[0m")
    if logs:
        for l in logs:
            if "level=ERROR" in l or "ERROR" in l:
                print(f"  \033[1;31m{l}\033[0m")
            elif "level=WARN" in l:
                print(f"  \033[1;33m{l}\033[0m")
            elif "stream" in l or "process" in l or "llm runtime" in l:
                print(f"  \033[1;32m{l}\033[0m")
            else:
                print(f"  \033[90m{l}\033[0m")
    else:
        print("  No log entries found.")

    print("\033[1;36m=====================================================\033[0m")

def main():
    parser = argparse.ArgumentParser(description="Monitor OpenCode execution status and logs.")
    parser.add_argument("-w", "--watch", action="store_true", help="Continuously monitor every N seconds")
    parser.add_argument("-i", "--interval", type=int, default=2, help="Watch interval in seconds (default: 2)")
    parser.add_argument("-n", "--lines", type=int, default=12, help="Number of recent log lines to display (default: 12)")
    parser.add_argument("-j", "--json", action="store_true", help="Output machine-readable JSON status")
    args = parser.parse_args()

    if args.json:
        data = get_status_data(args.lines)
        print(json.dumps(data, indent=2))
        return

    if args.watch:
        try:
            while True:
                os.system('clear' if os.name == 'posix' else 'cls')
                print_status(num_logs=args.lines)
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\nMonitoring stopped.")
    else:
        print_status(num_logs=args.lines)

if __name__ == '__main__':
    main()
