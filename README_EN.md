# Claude Code Index/Detail Context Compaction

An Index/Detail compaction tool for Claude Code. It hooks into **PreCompact** to generate a concise index and a detailed transcript, reducing token usage while preserving critical context.

## Overview
This tool generates a two-layer context snapshot before compaction:
- **Index layer**: decisions, constraints, TODOs, and open questions required to continue the task.
- **Detail layer**: the last ~30 raw messages for on‑demand recovery.

## Motivation
Claude Code compaction can drop key decisions or constraints in long conversations. This tool keeps the context lightweight while preserving recoverability via structured index + detailed transcript.

## Features
- PreCompact Hook generates `index.md` / `detail.md`
- Structured `index.json` / `detail.json`
- Lifecycle across rounds: Active / Updated / Archived / Dropped
- Interactive CLI selection (Keep / Drop / Pin / Archive)
- Snapshot history in `snapshots/`

## Prerequisites
- **Claude Code** installed
- **python3** available
- Permission to edit `~/.claude/settings.json`

## Installation
### 1) Copy the hook script
```bash
mkdir -p ~/.claude/hooks
cp ./precompact-index-detail.sh ~/.claude/hooks/precompact-index-detail.sh
chmod +x ~/.claude/hooks/precompact-index-detail.sh
```

### 2) Register the PreCompact hook
Edit `~/.claude/settings.json` and add under `hooks`:
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
> Replace with your actual path and merge with existing hooks.

## Configuration
- **Interactive toggle** (enabled by default):
  ```bash
  INDEX_DETAIL_INTERACTIVE=0
  ```

- **retain.json** (optional manual edits):
  ```json
  {
    "pinned_ids": [],
    "drop_ids": [],
    "manual_status": {
      "id": "archived"
    }
  }
  ```

## Usage
### 1) Normal Claude Code usage
When compaction triggers, the hook runs automatically.

### 2) Interactive selection
```
[Index/Detail] Select items (Enter=Keep, d=Drop, p=Pin, a=Archive, q=Quit)
```
- Enter/K = Keep
- d = Drop
- p = Pin
- a = Archive
- q = Quit

### 3) Manual test run
```bash
~/.claude/hooks/precompact-index-detail.sh
```

## Output structure
```
<project>/.claude/
  index.md
  detail.md
  index.json
  detail.json
  retain.json
  snapshots/
```

## Security & Privacy
- `$HOME` is redacted to `~` by default.
- All outputs are stored under the project’s `.claude/` directory.

## License
MIT
