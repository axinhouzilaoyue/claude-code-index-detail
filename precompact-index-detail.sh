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
RETAIN_JSON="$OUT_DIR/retain.json"

SNAP_INDEX_MD="$SNAP_DIR/$TIMESTAMP.index.md"
SNAP_DETAIL_MD="$SNAP_DIR/$TIMESTAMP.detail.md"
SNAP_INDEX_JSON="$SNAP_DIR/$TIMESTAMP.index.json"

export PROJECT_ROOT OUT_DIR SNAP_DIR TIMESTAMP INDEX_MD DETAIL_MD INDEX_JSON RETAIN_JSON SNAP_INDEX_MD SNAP_DETAIL_MD SNAP_INDEX_JSON

python3 - <<'PY'
import json
import os
import pathlib
import re
import sys
import hashlib

project_root = os.environ.get("PROJECT_ROOT") or os.getcwd()
out_dir = os.environ["OUT_DIR"]
snap_dir = os.environ["SNAP_DIR"]
timestamp = os.environ["TIMESTAMP"]
index_md = os.environ["INDEX_MD"]
detail_md = os.environ["DETAIL_MD"]
index_json = os.environ["INDEX_JSON"]
retain_json = os.environ["RETAIN_JSON"]
snap_index_md = os.environ["SNAP_INDEX_MD"]
snap_detail_md = os.environ["SNAP_DETAIL_MD"]
snap_index_json = os.environ["SNAP_INDEX_JSON"]

home = os.path.expanduser("~")
write_md = os.environ.get("INDEX_DETAIL_WRITE_MD", "1") != "0"


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


def stable_id(text: str) -> str:
    h = hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]
    return f"item_{h}"


def truncate(text: str, limit: int = 160):
    return text if len(text) <= limit else text[: limit - 1] + "…"


def clean_line(line: str) -> str:
    line = line.strip()
    line = re.sub(r"^[\s\-*\d\.]+", "", line)
    line = re.sub(r"\s+", " ", line).strip()
    return line


def make_title(line: str) -> str:
    line = clean_line(line)
    if not line:
        return ""
    if re.search(r"[\u4e00-\u9fff]", line):
        return truncate(line, 24)
    words = line.split()
    return truncate(" ".join(words[:8]), 60)


def make_description(line: str) -> str:
    return truncate(clean_line(line), 140)


def make_summary(line: str) -> str:
    return truncate(clean_line(line), 160)


def add_unique(lst, value):
    if value not in lst:
        lst.append(value)


def remove_if_present(lst, value):
    if value in lst:
        lst.remove(value)




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


def pick_session_from_index(sess_index: str):
    if not os.path.exists(sess_index):
        return None, None
    try:
        data = json.load(open(sess_index, "r", encoding="utf-8"))
    except Exception:
        return None, None
    entries = data.get("entries", [])
    if not entries:
        return None, None
    latest = max(entries, key=lambda e: e.get("modified") or e.get("fileMtime") or 0)
    return latest.get("fullPath"), latest.get("sessionId")


def pick_latest_jsonl(project_dir: str):
    if not os.path.isdir(project_dir):
        return None, None
    jsonls = [os.path.join(project_dir, name) for name in os.listdir(project_dir) if name.endswith(".jsonl")]
    if not jsonls:
        return None, None
    latest_path = max(jsonls, key=lambda p: os.path.getmtime(p))
    return latest_path, pathlib.Path(latest_path).stem


def render_index_md(data):
    lines = [
        "# Index (auto)",
        f"> Generated: {data.get('generated')}",
        f"> Project: {data.get('project')}",
        f"> Session: {data.get('session_id')}",
        f"> Source: {data.get('source')}",
        "",
        "## Cards"
    ]

    items = data.get("items", [])
    if not items:
        lines.append("- (none detected)")
        return "\n".join(lines).strip() + "\n"

    def fmt(item):
        flags = []
        if item.get("pinned"):
            flags.append("PIN")
        status = item.get("status")
        if status and status != "active":
            flags.append(status.upper())
        suffix = f" [{'|'.join(flags)}]" if flags else ""
        return f"- `{item.get('id')}` {item.get('title')} — {item.get('description')}{suffix}"

    for item in items:
        lines.append(fmt(item))

    return "\n".join(lines).strip() + "\n"


def render_detail_md(data):
    lines = [
        "# Detail (auto)",
        f"> Generated: {data.get('generated')}",
        f"> Project: {data.get('project')}",
        f"> Session: {data.get('session_id')}",
        f"> Source: {data.get('source')}",
        "",
        "## Cards"
    ]

    items = data.get("items", [])
    if not items:
        lines.append("- (none detected)")
        return "\n".join(lines).strip() + "\n"

    for item in items:
        status = item.get("status", "active")
        if item.get("pinned"):
            status = f"{status} (PIN)"
        detail = item.get("detail", {}) or {}
        summary = detail.get("summary", "")
        quote = detail.get("quote", "")

        lines.append(f"## {item.get('id')} — {item.get('title')}")
        lines.append(f"- Status: {status}")
        lines.append(f"- Summary: {summary}")
        lines.append("- Quote:")
        lines.append("```")
        lines.append(quote)
        lines.append("```")
        lines.append("")

    return "\n".join(lines).strip() + "\n"


def persist_outputs(index_data, retain_data):
    write_json(index_json, index_data)
    write_json(retain_json, retain_data)
    write_json(snap_index_json, index_data)
    if write_md:
        write_text(index_md, render_index_md(index_data))
        write_text(detail_md, render_detail_md(index_data))
        write_text(snap_index_md, render_index_md(index_data))
        write_text(snap_detail_md, render_detail_md(index_data))


# Load retain.json
retain = {}
if os.path.exists(retain_json):
    try:
        retain = json.load(open(retain_json, "r", encoding="utf-8"))
    except Exception:
        retain = {}

if not isinstance(retain, dict):
    retain = {}

retain.setdefault("pinned_ids", [])
retain.setdefault("drop_ids", [])
retain.setdefault("archived_ids", [])

manual_status = retain.get("manual_status")
if isinstance(manual_status, dict):
    for item_id, status in manual_status.items():
        if status == "archived":
            add_unique(retain["archived_ids"], item_id)
        elif status == "dropped":
            add_unique(retain["drop_ids"], item_id)
        elif status == "pinned":
            add_unique(retain["pinned_ids"], item_id)

# Load previous index.json
prev_index = {"items": []}
if os.path.exists(index_json):
    try:
        prev_index = json.load(open(index_json, "r", encoding="utf-8"))
    except Exception:
        prev_index = {"items": []}

prev_items = prev_index.get("items", [])

for prev in prev_items:
    pid = prev.get("id")
    if not pid:
        continue
    if prev.get("status") == "archived":
        add_unique(retain["archived_ids"], pid)
    if prev.get("status") == "dropped":
        add_unique(retain["drop_ids"], pid)
    if prev.get("pinned"):
        add_unique(retain["pinned_ids"], pid)


def cleaned_retain():
    return {
        "pinned_ids": list(dict.fromkeys(retain.get("pinned_ids", []))),
        "drop_ids": list(dict.fromkeys(retain.get("drop_ids", []))),
        "archived_ids": list(dict.fromkeys(retain.get("archived_ids", [])))
    }


sess_index = find_sessions_index(project_root)
project_dir = os.path.join(home, ".claude", "projects", project_root.replace("/", "-"))

# Prefer the newest session log between sessions-index and raw jsonl files
session_path = None
session_id = None

index_path = None
index_id = None
if os.path.exists(sess_index):
    index_path, index_id = pick_session_from_index(sess_index)

latest_path, latest_id = pick_latest_jsonl(project_dir)


def mtime(path: str) -> float:
    try:
        return os.path.getmtime(path)
    except Exception:
        return -1


if index_path and latest_path:
    if mtime(latest_path) >= mtime(index_path):
        session_path, session_id = latest_path, latest_id
    else:
        session_path, session_id = index_path, index_id
elif index_path:
    session_path, session_id = index_path, index_id
elif latest_path:
    session_path, session_id = latest_path, latest_id

if not session_path:
    index_data = {
        "version": 2,
        "generated": timestamp,
        "project": project_root,
        "session_id": None,
        "source": sess_index,
        "items": [],
        "status": "no session entries"
    }
    persist_outputs(index_data, cleaned_retain())
    raise SystemExit(0)

if not session_path or not os.path.exists(session_path):
    index_data = {
        "version": 2,
        "generated": timestamp,
        "project": project_root,
        "session_id": session_id,
        "source": session_path,
        "items": [],
        "status": "session log not found"
    }
    persist_outputs(index_data, cleaned_retain())
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
        "version": 2,
        "generated": timestamp,
        "project": project_root,
        "session_id": session_id,
        "source": session_path,
        "items": [],
        "status": "no text messages"
    }
    persist_outputs(index_data, cleaned_retain())
    raise SystemExit(0)


# Heuristics

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
    if "system-reminder" in t.lower():
        return True
    if "Called the Read tool" in t or "Result of calling the Read tool" in t:
        return True
    if t in {"Connected to Obsidian."}:
        return True
    return False


candidates = []
MAX_ITEMS = 12
SIM_THRESHOLD = 0.7


def add_candidate(line: str) -> bool:
    cleaned = clean_line(line)
    if not cleaned or len(cleaned) < 4:
        return False
    for c in candidates:
        if similarity(c["clean"], cleaned) >= SIM_THRESHOLD:
            return False
    candidates.append({"raw": line.strip(), "clean": cleaned})
    return True


for m in messages[-50:]:
    if is_noise(m["text"]):
        continue
    for raw_line in m["text"].splitlines():
        line = raw_line.strip()
        if not line or line.startswith("```"):
            continue
        add_candidate(line)
        if len(candidates) >= MAX_ITEMS:
            break
    if len(candidates) >= MAX_ITEMS:
        break


items = []
for cand in candidates:
    title = make_title(cand["clean"]) or make_title(cand["raw"])
    description = make_description(cand["clean"]) or make_description(cand["raw"])
    summary = make_summary(cand["clean"]) or make_summary(cand["raw"])
    quote = cand["raw"]
    items.append({
        "id": stable_id(description),
        "title": title,
        "description": description,
        "detail": {
            "summary": summary,
            "quote": quote
        },
        "status": "active",
        "pinned": False
    })


def prev_text(item) -> str:
    return item.get("description") or item.get("summary") or item.get("title") or ""


def normalize_prev_item(prev):
    text = redact(prev_text(prev))
    title = prev.get("title") or truncate(text, 48)
    description = prev.get("description") or prev.get("summary") or text
    detail = prev.get("detail")
    if isinstance(detail, dict):
        summary = detail.get("summary") or description
        quote = detail.get("quote") or text
    else:
        summary = description
        quote = text
    return {
        "id": prev.get("id") or stable_id(description),
        "title": truncate(title, 60),
        "description": truncate(description, 140),
        "detail": {
            "summary": truncate(summary, 160),
            "quote": quote
        },
        "status": "active",
        "pinned": bool(prev.get("pinned"))
    }


used_prev = set()
MATCH_THRESHOLD = 0.65

for item in items:
    best = None
    best_score = 0.0
    for prev in prev_items:
        pid = prev.get("id")
        if not pid or pid in used_prev:
            continue
        score = similarity(prev_text(prev), item.get("description", ""))
        if score > best_score:
            best_score = score
            best = prev
    if best and best_score >= MATCH_THRESHOLD:
        used_prev.add(best.get("id"))
        item["id"] = best.get("id", item["id"])
        if best.get("pinned"):
            item["pinned"] = True

retain_ids_to_keep = set(retain.get("pinned_ids", [])) | set(retain.get("archived_ids", [])) | set(retain.get("drop_ids", []))

for prev in prev_items:
    pid = prev.get("id")
    if not pid or pid in used_prev:
        continue
    if prev.get("pinned") or pid in retain_ids_to_keep:
        items.append(normalize_prev_item(prev))

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
    for item in items[:]:
        prompt = f"{item['title']} — {item['description']}"
        print(prompt)
        try:
            choice = input_fn("选择 (K/d/p/a/q): ").strip().lower()
        except Exception:
            choice = ""
        if choice == "q":
            break
        if choice == "d":
            add_unique(retain["drop_ids"], item["id"])
            remove_if_present(retain["pinned_ids"], item["id"])
            remove_if_present(retain["archived_ids"], item["id"])
        elif choice == "p":
            add_unique(retain["pinned_ids"], item["id"])
            remove_if_present(retain["drop_ids"], item["id"])
            remove_if_present(retain["archived_ids"], item["id"])
        elif choice == "a":
            add_unique(retain["archived_ids"], item["id"])
            remove_if_present(retain["pinned_ids"], item["id"])
            remove_if_present(retain["drop_ids"], item["id"])
        else:
            # keep
            pass
    if tty:
        tty.close()

# Apply retain rules
pinned_ids = set(retain.get("pinned_ids", []))
drop_ids = set(retain.get("drop_ids", []))
archived_ids = set(retain.get("archived_ids", []))

final_items = []
seen_ids = set()

for item in items:
    item_id = item.get("id")
    if not item_id or item_id in seen_ids:
        continue
    seen_ids.add(item_id)

    if item_id in drop_ids:
        item["status"] = "dropped"
        item["pinned"] = False
    elif item_id in archived_ids:
        item["status"] = "archived"
        item["pinned"] = False
    else:
        item["status"] = "active"
        if item_id in pinned_ids:
            item["pinned"] = True

    final_items.append(item)

status_order = {"active": 0, "archived": 1, "dropped": 2}
final_items.sort(key=lambda i: (status_order.get(i.get("status"), 9), 0 if i.get("pinned") else 1))

# Build JSON outputs
index_data = {
    "version": 2,
    "generated": timestamp,
    "project": project_root,
    "session_id": session_id,
    "source": session_path,
    "items": final_items
}

# Persist outputs
persist_outputs(index_data, cleaned_retain())
PY
