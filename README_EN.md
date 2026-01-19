# Claude Code Index/Detail Context Compaction

An Index/Detail compaction tool for Claude Code. It hooks into **PreCompact** to generate a concise index and a detailed transcript, reducing token usage while preserving critical context.

---

## Why this tool
Claude Code may compact long conversations, which can drop important decisions or constraints. This tool implements a **dual-layer memory**:

- **Index layer**: decisions, constraints, TODOs, and open questions needed to continue the task.
- **Detail layer**: full excerpts for on-demand recovery.

This keeps the conversation lightweight while preserving recoverability.

---

## What it does
- Generates `index.md` + `detail.md` before compaction
- Outputs structured `index.json` / `detail.json`
- Multi-round lifecycle: Active / Updated / Archived / Dropped
- Interactive CLI selection (Keep / Drop / Pin / Archive)
- Snapshot history under `snapshots/`

---

## Installation

### 1) Copy the hook script
Save the script to:
```
~/.claude/hooks/precompact-index-detail.sh
```
Make it executable:
```bash
chmod +x ~/.claude/hooks/precompact-index-detail.sh
```

### 2) Register the PreCompact hook
Edit `~/.claude/settings.json` and add:
```json
"PreCompact": [
  {
    "matcher": "*",
    "hooks": [
      {"type": "command", "command": "/Users/<your_user>/.claude/hooks/precompact-index-detail.sh"}
    ]
  }
]
```
> Replace with your actual path.

---

## Usage

### 1) Normal Claude Code usage
When Claude Code compaction triggers, the hook runs automatically.

### 2) Interactive selection
You will see:
```
[Index/Detail] Select items (Enter=Keep, d=Drop, p=Pin, a=Archive, q=Quit)
```
- Enter/K = Keep
- d = Drop
- p = Pin
- a = Archive
- q = Quit

### 3) Output location
Files are written to:
```
<project>/.claude/
  index.md
  detail.md
  index.json
  detail.json
  retain.json
  snapshots/
```

### 4) Manual test run
```bash
~/.claude/hooks/precompact-index-detail.sh
```

---

## Notes
- `$HOME` is redacted to `~` by default
- Disable interactive mode with:
```bash
INDEX_DETAIL_INTERACTIVE=0
```

---

## License
MIT
