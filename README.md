# Claude Code Index/Detail Context Compaction

为 Claude Code 提供一个“Index/Detail”上下文压缩工具，通过 PreCompact Hook 自动生成索引与细节记录，避免长对话丢失关键信息。

---

## 为什么做这个工具
Claude Code 在长对话中会触发上下文压缩。传统压缩方式容易丢失细节或关键约束。本工具采用 **Index/Detail** 的双层结构：

- **Index（索引层）**：保留继续对话所需的关键信息（决策、约束、待办、问题）。
- **Detail（细节层）**：保存完整片段与细节，按需回溯。

这样可以在压缩时降低 token 占用，同时保证后续对话仍可恢复上下文。

---

## 这个工具能做什么
- 在压缩前自动生成：`index.md` + `detail.md`
- 同步输出结构化 `index.json` / `detail.json`
- 支持多轮压缩生命周期（Active / Updated / Archived / Dropped）
- 支持交互式 CLI 选择保留项（Keep / Drop / Pin / Archive）
- 自动生成快照历史（snapshots）

---

## 安装（让朋友也能用）

### 1) 拷贝 Hook 脚本
将以下脚本保存到：
```
~/.claude/hooks/precompact-index-detail.sh
```
并赋予执行权限：
```bash
chmod +x ~/.claude/hooks/precompact-index-detail.sh
```

### 2) 注册 PreCompact Hook
编辑 `~/.claude/settings.json`，加入：
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
> 注意替换为你的实际路径。

---

## 使用方式

### 1) 正常使用 Claude Code
当上下文接近上限触发压缩时，Hook 会自动执行。

### 2) CLI 交互式保留
压缩时会看到提示：
```
[Index/Detail] 选择保留项 (Enter=Keep, d=Drop, p=Pin, a=Archive, q=Quit)
```
- Enter/K = Keep
- d = Drop
- p = Pin
- a = Archive
- q = Quit

### 3) 输出位置
生成文件在项目内：
```
<project>/.claude/
  index.md
  detail.md
  index.json
  detail.json
  retain.json
  snapshots/
```

### 4) 手动运行（测试）
```bash
~/.claude/hooks/precompact-index-detail.sh
```

---

## 备注
- 默认会脱敏 `$HOME` 路径为 `~`
- 可通过 `INDEX_DETAIL_INTERACTIVE=0` 关闭交互模式

---

## License
MIT
