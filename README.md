# Claude Code Index/Detail Context Compaction

面向 Claude Code 的 Index/Detail 上下文压缩工具。通过 PreCompact Hook 在压缩前生成索引与细节记录，降低 token 压力并保留关键上下文。

## 项目简介
该工具在上下文压缩前自动生成两层信息：
- **Index（索引层）**：决策、约束、待办、问题等可持续对话信息。
- **Detail（细节层）**：近 30 条对话原文，支持按需回溯。

## 设计动机
Claude Code 在长对话中会触发上下文压缩，传统摘要容易丢失关键约束或历史决策。本工具用结构化索引 + 可回溯细节的方式，保证对话连续性与可追踪性。

## 功能特性
- PreCompact Hook 自动生成 `index.md` / `detail.md`
- 同步输出结构化 `index.json` / `detail.json`
- 多轮生命周期：Active / Updated / Archived / Dropped
- 交互式 CLI 选择保留项（Keep / Drop / Pin / Archive）
- 快照归档（snapshots）

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

- **retain.json**（可手动编辑）：
  ```json
  {
    "pinned_ids": [],
    "drop_ids": [],
    "manual_status": {
      "id": "archived"
    }
  }
  ```

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

### 3) 手动运行（测试）
```bash
~/.claude/hooks/precompact-index-detail.sh
```

## 输出结构
```
<project>/.claude/
  index.md
  detail.md
  index.json
  detail.json
  retain.json
  snapshots/
```

## 安全与隐私
- 自动将 `$HOME` 替换为 `~` 进行脱敏。
- 所有输出保存在项目内 `.claude/`，便于自行管理与清理。

## License
MIT
