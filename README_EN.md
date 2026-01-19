# Claude Code Index/Detail Context Compaction

An Index/Detail compaction tool for Claude Code. It hooks into **PreCompact** to generate simplified cards (Index) and on-demand details (Detail), reducing token usage while preserving critical context.

## Overview
This tool generates a two-layer context snapshot before compaction:
- **Index layer**: card list (`id / title / description / status / pinned`).
- **Detail layer**: per-card `summary + quote` located by `id`.

## Motivation
Claude Code compaction can drop key decisions or constraints in long conversations. This tool keeps the context lightweight while preserving recoverability via structured index + detail cards.

## Features
- Structured `index.json` (detail merged into each item; no `detail.json` output)
- Optional `index.md` / `detail.md` output (enabled by default)
- Lifecycle across rounds: Active / Archived / Dropped
- Interactive CLI selection (Keep / Drop / Pin / Archive)
- Snapshot history in `snapshots/`
- 1:1 Index/Detail mapping with `id`-based loading

## Card schema (JSON)
```json
{
  "id": "item_xxx",
  "title": "<short title>",
  "description": "<1-sentence summary>",
  "detail": {
    "summary": "<1-2 sentence recap>",
    "quote": "<raw excerpt>"
  },
  "status": "active|archived|dropped",
  "pinned": false
}
```

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

- **Markdown output toggle** (enabled by default):
  ```bash
  INDEX_DETAIL_WRITE_MD=0
  ```
  Set to `0` to only output `index.json` / `retain.json` (no `index.md` / `detail.md`).

- **retain.json** (optional manual edits):
  ```json
  {
    "pinned_ids": [],
    "drop_ids": [],
    "archived_ids": []
  }
  ```
  > If older versions included `manual_status`, the script migrates it into these three lists.

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

### 3) Load detail by id
1) Find the target `id` in `index.md`.
2) Search for `## <id> — <title>` in `detail.md`.

(Optional) Add a local helper function:
```bash
show-detail() {
  local id="$1"
  sed -n "/^## ${id} —/,/^## /p" ".claude/detail.md"
}
```

### 4) Manual test run
```bash
~/.claude/hooks/precompact-index-detail.sh
```

## Output structure
```
<project>/.claude/
  index.json
  retain.json
  snapshots/
    <ts>.index.json

# Optional (enabled by default):
# index.md
# detail.md
# snapshots/<ts>.index.md
# snapshots/<ts>.detail.md
```

## Security & Privacy
- `$HOME` is redacted to `~` by default.
- All outputs are stored under the project’s `.claude/` directory.

## License
MIT
