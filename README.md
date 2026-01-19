# Claude Code Index/Detail Context Compaction

面向 Claude Code 的 Index/Detail 上下文压缩工具。通过 PreCompact Hook 在压缩前生成简化卡片（Index）与可回溯细节（Detail），降低 token 压力并保留关键上下文。

## 项目简介
该工具在上下文压缩前自动生成两层信息：
- **Index（索引层）**：卡片清单（`id / title / description / status / pinned`）。
- **Detail（细节层）**：每条卡片的 `summary + quote`（按 `id` 定位）。

## 设计动机
Claude Code 在长对话中会触发上下文压缩，传统摘要容易丢失关键约束或历史决策。本工具用结构化索引 + 可回溯细节的方式，保证对话连续性与可追踪性。

## 功能特性
- 结构化 `index.json`（detail 合并进条目，不再输出 `detail.json`）
- 可选生成 `index.md` / `detail.md`（默认开启）
- 生命周期：Active / Archived / Dropped
- 交互式 CLI 选择保留项（Keep / Drop / Pin / Archive）
- 快照归档（snapshots）
- Index/Detail 1:1 对应（按 `id` 动态加载 detail）

## 卡片结构（JSON）
```json
{
  "id": "item_xxx",
  "title": "<短标题>",
  "description": "<1 句概括>",
  "detail": {
    "summary": "<1-2 句归纳>",
    "quote": "<原文片段>"
  },
  "status": "active|archived|dropped",
  "pinned": false
}
```

## 运行前提
- 已安装 **Claude Code**
- 本地可用 **python3**
- 具备编辑 `~/.claude/settings.json` 的权限

## 安装
### 1) 拷贝 Hook 脚本
```bash
mkdir -p ~/.claude/hooks
cp ./precompact-index-detail.sh ~/.claude/hooks/precompact-index-detail.sh
chmod +x ~/.claude/hooks/precompact-index-detail.sh
```

### 2) 注册 PreCompact Hook
在 `~/.claude/settings.json` 的 `hooks` 下新增：
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
> 注意替换为你的实际路径，并与已有 hooks 合并。

## 配置说明
- **交互模式开关**（默认开启）：
  ```bash
  INDEX_DETAIL_INTERACTIVE=0
  ```
  设为 `0` 则关闭 CLI 选择流程。

- **Markdown 输出开关**（默认开启）：
  ```bash
  INDEX_DETAIL_WRITE_MD=0
  ```
  设为 `0` 则仅输出 `index.json` / `retain.json`（不生成 `index.md` / `detail.md`）。

- **retain.json**（可手动编辑）：
  ```json
  {
    "pinned_ids": [],
    "drop_ids": [],
    "archived_ids": []
  }
  ```
  > 若之前版本存在 `manual_status` 字段，脚本会迁移并合并到以上三类。

## 使用方式
### 1) 正常使用 Claude Code
当触发上下文压缩时，Hook 自动运行。

### 2) 交互式选择保留项
```
[Index/Detail] 选择保留项 (Enter=Keep, d=Drop, p=Pin, a=Archive, q=Quit)
```
- Enter/K = Keep
- d = Drop
- p = Pin
- a = Archive
- q = Quit

### 3) 按 ID 加载 detail
1) 在 `index.md` 中找到目标 `id`。
2) 在 `detail.md` 中搜索 `## <id> — <title>`。

（可选）添加本地函数便于查看：
```bash
show-detail() {
  local id="$1"
  sed -n "/^## ${id} —/,/^## /p" ".claude/detail.md"
}
```

### 4) 手动运行（测试）
```bash
~/.claude/hooks/precompact-index-detail.sh
```

## 输出结构
```
<project>/.claude/
  index.json
  retain.json
  snapshots/
    <ts>.index.json

# 可选（默认开启）：
# index.md
# detail.md
# snapshots/<ts>.index.md
# snapshots/<ts>.detail.md
```

## 安全与隐私
- 自动将 `$HOME` 替换为 `~` 进行脱敏。
- 所有输出保存在项目内 `.claude/`，便于自行管理与清理。

## License
MIT
