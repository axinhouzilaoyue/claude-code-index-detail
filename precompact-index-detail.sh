#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"
OUT_DIR="$PROJECT_ROOT/.claude"
SNAP_DIR="$OUT_DIR/snapshots"
mkdir -p "$SNAP_DIR"

TIMESTAMP="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
INDEX_MD="$OUT_DIR/index.md"
DETAIL_MD="$OUT_DIR/detail.md"
INDEX_JSON="$OUT_DIR/index.json"
DETAIL_JSON="$OUT_DIR/detail.json"
RETAIN_JSON="$OUT_DIR/retain.json"

SNAP_INDEX_MD="$SNAP_DIR/$TIMESTAMP.index.md"
SNAP_DETAIL_MD="$SNAP_DIR/$TIMESTAMP.detail.md"
SNAP_INDEX_JSON="$SNAP_DIR/$TIMESTAMP.index.json"
SNAP_DETAIL_JSON="$SNAP_DIR/$TIMESTAMP.detail.json"

export PROJECT_ROOT OUT_DIR SNAP_DIR TIMESTAMP INDEX_MD DETAIL_MD INDEX_JSON DETAIL_JSON RETAIN_JSON SNAP_INDEX_MD SNAP_DETAIL_MD SNAP_INDEX_JSON SNAP_DETAIL_JSON

python3 - <<'PY'
import json
import os
import pathlib
import re
import sys
import hashlib
from datetime import datetime, timezone

project_root = os.environ.get("PROJECT_ROOT") or os.getcwd()
out_dir = os.environ["OUT_DIR"]
snap_dir = os.environ["SNAP_DIR"]
timestamp = os.environ["TIMESTAMP"]
index_md = os.environ["INDEX_MD"]
detail_md = os.environ["DETAIL_MD"]
index_json = os.environ["INDEX_JSON"]
detail_json = os.environ["DETAIL_JSON"]
retain_json = os.environ["RETAIN_JSON"]
snap_index_md = os.environ["SNAP_INDEX_MD"]
snap_detail_md = os.environ["SNAP_DETAIL_MD"]
snap_index_json = os.environ["SNAP_INDEX_JSON"]
snap_detail_json = os.environ["SNAP_DETAIL_JSON"]

home = os.path.expanduser("~")

def redact(text: str) -> str:
    return text.replace(home, "~")

def write_text(path: str, content: str) -> None:
    pathlib.Path(path).write_text(content, encoding="utf-8")

def write_json(path: str, data) -> None:
    pathlib.Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def tokenize(s: str):
    s = s.lower()
    if re.search(r"[\u4e00-\u9fff]", s):
        return {c for c in s if not c.isspace()}
    return set(re.findall(r"[a-z0-9]+", s))

def similarity(a: str, b: str) -> float:
    ta, tb = tokenize(a), tokenize(b)
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)

def stable_id(item_type: str, summary: str) -> str:
    h = hashlib.sha1(f"{item_type}:{summary}".encode("utf-8")).hexdigest()[:12]
    return f"{item_type}_{h}"

def truncate(text: str, limit: int = 160):
    return text if len(text) <= limit else text[: limit - 1] + "…"

# Locate sessions-index.json

def find_sessions_index(project_root: str) -> str:
    key = project_root.replace("/", "-")
    candidate = os.path.join(home, ".claude", "projects", key, "sessions-index.json")
    if os.path.exists(candidate):
        return candidate

    base = os.path.join(home, ".claude", "projects")
    try:
        for name in os.listdir(base):
            path = os.path.join(base, name, "sessions-index.json")
            if not os.path.exists(path):
                continue
            try:
                data = json.load(open(path, "r", encoding="utf-8"))
            except Exception:
                continue
            for entry in data.get("entries", []):
                if (entry.get("projectPath") or "").lower() == project_root.lower():
                    return path
    except FileNotFoundError:
        pass

    return candidate

sess_index = find_sessions_index(project_root)

# Load retain.json
retain = {"pinned_ids": [], "drop_ids": [], "manual_status": {}}
if os.path.exists(retain_json):
    try:
        retain = json.load(open(retain_json, "r", encoding="utf-8"))
    except Exception:
        pass

# Load previous index.json
prev_index = {"items": [], "history": []}
if os.path.exists(index_json):
    try:
        prev_index = json.load(open(index_json, "r", encoding="utf-8"))
    except Exception:
        pass

prev_items = prev_index.get("items", [])

# If no sessions-index.json
if not os.path.exists(sess_index):
    index_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": None,
        "source": sess_index,
        "items": [],
        "history": [],
        "status": "sessions-index.json not found"
    }
    detail_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": None,
        "source": sess_index,
        "chunks": []
    }
    write_json(index_json, index_data)
    write_json(detail_json, detail_data)
    write_text(index_md, "# Index (auto)\n")
    write_text(detail_md, "# Detail (auto)\n")
    write_json(snap_index_json, index_data)
    write_json(snap_detail_json, detail_data)
    write_text(snap_index_md, pathlib.Path(index_md).read_text(encoding="utf-8"))
    write_text(snap_detail_md, pathlib.Path(detail_md).read_text(encoding="utf-8"))
    raise SystemExit(0)

with open(sess_index, "r", encoding="utf-8") as f:
    data = json.load(f)

entries = data.get("entries", [])
if not entries:
    index_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": None,
        "source": sess_index,
        "items": [],
        "history": [],
        "status": "no session entries"
    }
    detail_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": None,
        "source": sess_index,
        "chunks": []
    }
    write_json(index_json, index_data)
    write_json(detail_json, detail_data)
    write_text(index_md, "# Index (auto)\n")
    write_text(detail_md, "# Detail (auto)\n")
    write_json(snap_index_json, index_data)
    write_json(snap_detail_json, detail_data)
    write_text(snap_index_md, pathlib.Path(index_md).read_text(encoding="utf-8"))
    write_text(snap_detail_md, pathlib.Path(detail_md).read_text(encoding="utf-8"))
    raise SystemExit(0)

latest = max(entries, key=lambda e: e.get("modified") or e.get("fileMtime") or 0)
session_path = latest.get("fullPath")
session_id = latest.get("sessionId")

if not session_path or not os.path.exists(session_path):
    index_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": session_id,
        "source": session_path,
        "items": [],
        "history": [],
        "status": "session log not found"
    }
    detail_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": session_id,
        "source": session_path,
        "chunks": []
    }
    write_json(index_json, index_data)
    write_json(detail_json, detail_data)
    write_text(index_md, "# Index (auto)\n")
    write_text(detail_md, "# Detail (auto)\n")
    write_json(snap_index_json, index_data)
    write_json(snap_detail_json, detail_data)
    write_text(snap_index_md, pathlib.Path(index_md).read_text(encoding="utf-8"))
    write_text(snap_detail_md, pathlib.Path(detail_md).read_text(encoding="utf-8"))
    raise SystemExit(0)

# Parse session log
messages = []

with open(session_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue

        msg = obj.get("message", {})
        role = msg.get("role") or obj.get("type")
        if role not in ("user", "assistant"):
            continue

        content = msg.get("content")
        text = ""
        if isinstance(content, str):
            text = content
        elif isinstance(content, list):
            parts = []
            for item in content:
                if item.get("type") == "text":
                    parts.append(item.get("text", ""))
            text = "".join(parts)

        text = re.sub(r"<[^>]+>", "", text or "").strip()
        if not text:
            continue

        messages.append({
            "role": role,
            "text": redact(text),
            "timestamp": obj.get("timestamp") or ""
        })

if not messages:
    index_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": session_id,
        "source": session_path,
        "items": [],
        "history": [],
        "status": "no text messages"
    }
    detail_data = {
        "version": 1,
        "generated": timestamp,
        "project": project_root,
        "session_id": session_id,
        "source": session_path,
        "chunks": []
    }
    write_json(index_json, index_data)
    write_json(detail_json, detail_data)
    write_text(index_md, "# Index (auto)\n")
    write_text(detail_md, "# Detail (auto)\n")
    write_json(snap_index_json, index_data)
    write_json(snap_detail_json, detail_data)
    write_text(snap_index_md, pathlib.Path(index_md).read_text(encoding="utf-8"))
    write_text(snap_detail_md, pathlib.Path(detail_md).read_text(encoding="utf-8"))
    raise SystemExit(0)

# Heuristics
latest_user = next((m for m in reversed(messages) if m["role"] == "user"), None)
text_window = messages[-50:]
recent = messages[-3:]

keywords_decisions = ["决定", "采用", "使用", "选择", "改为", "计划"]
keywords_constraints = ["不要", "禁止", "必须", "避免", "不得", "不能", "敏感", "隐私"]
keywords_todos = ["TODO", "待办", "- [ ]"]


def find_lines(msgs, keywords):
    found = []
    for m in msgs:
        for line in m["text"].splitlines():
            if any(k in line for k in keywords):
                line = line.strip()
                if line and line not in found:
                    found.append(line)
    return found[:5]


def extract_questions(text: str):
    if not text:
        return []
    parts = re.split(r"[?？]", text)
    qs = [p.strip() for p in parts[:-1] if p.strip()]
    return [q + "?" for q in qs[:5]]


def is_noise(text: str):
    t = text.strip()
    if not t:
        return True
    if "Caveat:" in t and "DO NOT respond" in t:
        return True
    if t.startswith("/"):
        return True
    if "command-name" in t or "command-args" in t or "command-message" in t:
        return True
    if t in {"Connected to Obsidian."}:
        return True
    return False

latest_user_clean = next((m for m in reversed(messages) if m["role"] == "user" and not is_noise(m["text"])), latest_user)

# Build detail chunks
chunks = []
for i, m in enumerate(messages[-30:]):
    cid = f"det_{hashlib.sha1((m['timestamp'] + str(i)).encode('utf-8')).hexdigest()[:10]}"
    chunks.append({
        "id": cid,
        "role": m["role"],
        "timestamp": m["timestamp"],
        "text": m["text"]
    })

chunk_ids = [c["id"] for c in chunks[-3:]]

# Candidate items
candidates = []

def add_item(item_type: str, summary: str):
    summary = truncate(summary)
    if not summary:
        return
    candidates.append({
        "id": stable_id(item_type, summary),
        "type": item_type,
        "summary": summary,
        "status": "active",
        "pinned": False,
        "detail_refs": chunk_ids,
        "source": "heuristic",
        "created_at": timestamp,
        "updated_at": timestamp
    })

if latest_user_clean and latest_user_clean.get("text") and not is_noise(latest_user_clean["text"]):
    add_item("focus", f"{latest_user_clean['text']}")

for d in find_lines(text_window, keywords_decisions):
    add_item("decision", d)

for c in find_lines(text_window, keywords_constraints):
    add_item("constraint", c)

for t in find_lines(text_window, keywords_todos):
    add_item("todo", t)

for q in extract_questions(latest_user_clean["text"] if latest_user_clean else ""):
    add_item("question", q)

# Match with previous items
threshold = 0.6
used_prev = set()
active_items = []
history_items = []

for cand in candidates:
    best = None
    best_score = 0.0
    for prev in prev_items:
        if prev.get("type") != cand["type"]:
            continue
        if prev.get("id") in used_prev:
            continue
        score = similarity(prev.get("summary", ""), cand.get("summary", ""))
        if score > best_score:
            best_score = score
            best = prev
    if best and best_score >= threshold:
        used_prev.add(best.get("id"))
        cand["id"] = best.get("id")
        if best.get("summary") != cand.get("summary"):
            cand["status"] = "updated"
            history_items.append({**best, "status": "updated", "updated_to": cand["id"], "updated_at": timestamp})
        cand["pinned"] = bool(best.get("pinned"))
    active_items.append(cand)

# Carry over pinned prev items not matched
for prev in prev_items:
    if prev.get("id") in used_prev:
        continue
    if prev.get("pinned"):
        active_items.append({**prev, "status": "active", "updated_at": timestamp})
    else:
        status = "archived"
        if prev.get("id") in retain.get("drop_ids", []):
            status = "dropped"
        history_items.append({**prev, "status": status, "updated_at": timestamp})

# Interactive CLI
interactive_flag = os.environ.get("INDEX_DETAIL_INTERACTIVE", "1") != "0"
input_fn = None
tty = None
if interactive_flag:
    if sys.stdin.isatty():
        input_fn = input
    else:
        try:
            tty = open("/dev/tty", "r")
            def input_fn(prompt=""):
                sys.stdout.write(prompt)
                sys.stdout.flush()
                return tty.readline().strip()
        except Exception:
            input_fn = None

if input_fn:
    print("\n[Index/Detail] 选择保留项 (Enter=Keep, d=Drop, p=Pin, a=Archive, q=Quit)")
    for item in active_items[:]:
        prompt = f"[{item['type']}] {item['summary']}"
        print(prompt)
        try:
            choice = input_fn("选择 (K/d/p/a/q): ").strip().lower()
        except Exception:
            choice = ""
        if choice == "q":
            break
        if choice == "d":
            retain.setdefault("drop_ids", []).append(item["id"])
            item["status"] = "dropped"
        elif choice == "p":
            retain.setdefault("pinned_ids", []).append(item["id"])
            item["pinned"] = True
        elif choice == "a":
            retain.setdefault("manual_status", {})[item["id"]] = "archived"
            item["status"] = "archived"
        else:
            # keep
            pass
    if tty:
        tty.close()

# Apply retain rules
pinned_ids = set(retain.get("pinned_ids", []))
drop_ids = set(retain.get("drop_ids", []))
manual_status = retain.get("manual_status", {})

final_active = []
for item in active_items:
    if item["id"] in drop_ids:
        history_items.append({**item, "status": "dropped", "updated_at": timestamp})
        continue
    if item["id"] in pinned_ids:
        item["pinned"] = True
    if item["id"] in manual_status:
        st = manual_status[item["id"]]
        if st in ("archived", "dropped"):
            history_items.append({**item, "status": st, "updated_at": timestamp})
            continue
        if st == "pinned":
            item["pinned"] = True
    item["status"] = "active" if item.get("status") not in ("updated",) else item.get("status")
    final_active.append(item)

# Render MD

def render_index_md(data):
    lines = [
        "# Index (auto)",
        f"> Generated: {data.get('generated')}",
        f"> Project: {data.get('project')}",
        f"> Session: {data.get('session_id')}",
        f"> Source: {data.get('source')}",
        ""
    ]

    by_type = {}
    for item in data.get("items", []):
        by_type.setdefault(item.get("type", "other"), []).append(item)

    def fmt(item):
        flags = []
        if item.get("pinned"):
            flags.append("PIN")
        if item.get("status") == "updated":
            flags.append("UPDATED")
        suffix = f" [{'|'.join(flags)}]" if flags else ""
        return f"- {item.get('summary')}{suffix}"

    for t in ["focus", "decision", "constraint", "todo", "question"]:
        if t in by_type:
            title = t.capitalize() if t != "todo" else "Todo"
            lines += [f"## {title}"]
            lines += [fmt(i) for i in by_type[t]]
            lines.append("")

    # History summary
    hist = data.get("history", [])
    if hist:
        lines += ["## History (archived/updated/dropped)"]
        for h in hist[-10:]:
            lines.append(f"- {h.get('summary')} [{h.get('status')}]" )
        lines.append("")

    return "\n".join(lines).strip() + "\n"


def render_detail_md(data):
    lines = [
        "# Detail (auto)",
        f"> Generated: {data.get('generated')}",
        f"> Project: {data.get('project')}",
        f"> Session: {data.get('session_id')}",
        f"> Source: {data.get('source')}",
        "",
        "## Transcript (last 30 messages)"
    ]
    for chunk in data.get("chunks", []):
        lines.append(f"### {chunk.get('role')} @ {chunk.get('timestamp')}")
        lines.append(chunk.get("text", ""))
        lines.append("")
    return "\n".join(lines).strip() + "\n"

# Build JSON outputs
index_data = {
    "version": 1,
    "generated": timestamp,
    "project": project_root,
    "session_id": session_id,
    "source": session_path,
    "items": final_active,
    "history": history_items
}

detail_data = {
    "version": 1,
    "generated": timestamp,
    "project": project_root,
    "session_id": session_id,
    "source": session_path,
    "chunks": chunks
}

# Persist outputs
write_json(index_json, index_data)
write_json(detail_json, detail_data)
write_json(retain_json, retain)
write_text(index_md, render_index_md(index_data))
write_text(detail_md, render_detail_md(detail_data))

# Snapshots
write_json(snap_index_json, index_data)
write_json(snap_detail_json, detail_data)
write_text(snap_index_md, render_index_md(index_data))
write_text(snap_detail_md, render_detail_md(detail_data))
PY
