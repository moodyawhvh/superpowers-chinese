> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# OpenCode 的 Superpowers

在 [OpenCode.ai](https://opencode.ai) 中使用 Superpowers 的完整指南。

## 安装

把 superpowers 添加到 `opencode.json`(全局或项目级)的 `plugin` 数组中:

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]
}
```

重启 OpenCode。插件会通过 OpenCode 的插件管理器完成安装,并注册所有技能。

可以用这句话验证:"介绍一下你掌握的 superpowers"

OpenCode 使用自己的插件安装机制。如果你同时使用 Claude Code、Codex 或其他 harness,请为每一个单独安装 Superpowers。

### 从旧的符号链接安装方式迁移

如果你之前是用 `git clone` 加符号链接的方式安装的 superpowers,请先清除旧配置:

```bash
# 删除旧的符号链接
rm -f ~/.config/opencode/plugins/superpowers.js
rm -rf ~/.config/opencode/skills/superpowers

# (可选)删除克隆下来的仓库
rm -rf ~/.config/opencode/superpowers

# 如果之前为 superpowers 添加过 skills.paths,请从 opencode.json 中移除
```

然后按上文的安装步骤操作。

## 使用

### 查找技能

使用 OpenCode 原生的 `skill` 工具列出所有可用技能:

```
use skill tool to list skills
```

### 加载技能

```
use skill tool to load brainstorming
```

### 个人技能

在 `~/.config/opencode/skills/` 中创建你自己的技能:

```bash
mkdir -p ~/.config/opencode/skills/my-skill
```

创建 `~/.config/opencode/skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: Use when [condition] - [what it does]
---

# My Skill

[Your skill content here]
```

### 项目技能

在项目的 `.opencode/skills/` 目录中创建项目专属技能。

**技能优先级:** 项目技能 > 个人技能 > Superpowers 技能

## 更新

OpenCode 通过基于 git 的包规格安装 Superpowers。某些版本的 OpenCode 和 Bun 会把解析出的 git 依赖固定在 lockfile 或缓存中,导致重启后拿不到最新的 Superpowers 提交。如果看不到更新,请清理 OpenCode 的包缓存或重新安装插件。

要固定某个版本,可以使用分支或标签:

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git#v5.0.3"]
}
```

## 工作原理

这个插件做两件事:

1. **注入引导上下文**:通过 `experimental.chat.messages.transform` hook,让每段对话都具备 superpowers 感知。
2. **注册技能目录**:通过 `config` hook 注册技能目录,让 OpenCode 无需符号链接或手工配置即可发现所有 superpowers 技能。

### 工具映射

技能用动作来描述,而不点名某个运行时的具体工具。在 OpenCode 上,它们解析为:

- "创建 todo" / "在 todo 列表中标记完成" → `todowrite`
- `Subagent (general-purpose):` 模板 → OpenCode 的 `task` 工具,`subagent_type: "general"`(代码库探索用 `"explore"`)
- "调用技能" → OpenCode 原生的 `skill` 工具
- "读取文件" → `read`
- "创建文件" / "编辑文件" / "删除文件" → `apply_patch`
- "运行 shell 命令" → `bash`
- "搜索文件内容" / "按名称查找文件" → `grep`、`glob`
- "抓取 URL" → `webfetch`

(已对照已安装的 OpenCode CLI 工具清单验证。)

## 故障排查

### 插件未加载

1. 查看 OpenCode 日志:`opencode run --print-logs "hello" 2>&1 | grep -i superpowers`
2. 检查 `opencode.json` 中的插件配置行是否正确
3. 确认你使用的是较新版本的 OpenCode

### Windows 安装问题

部分 Windows 版 OpenCode 在处理基于 git 的插件规格时存在上游安装器问题,包括 `git+https` URL 的缓存路径,以及 Bun 在普通终端里明明能用 `git.exe` 却找不到它。如果 OpenCode 无法安装插件,可以尝试用系统的 npm 安装,再让 OpenCode 指向本地包:

```powershell
npm install superpowers@git+https://github.com/obra/superpowers.git --prefix "$HOME\.config\opencode"
```

然后在 `opencode.json` 中使用已安装包的路径:

```json
{
  "plugin": ["~/.config/opencode/node_modules/superpowers"]
}
```

### 找不到技能

1. 使用 OpenCode 的 `skill` 工具列出可用技能
2. 检查插件是否正常加载(见上文)
3. 每个技能都需要一个带有效 YAML frontmatter 的 `SKILL.md` 文件

### 引导上下文未出现

1. 检查 OpenCode 版本是否支持 `experimental.chat.messages.transform` hook
2. 修改配置后重启 OpenCode

## 获取帮助

- 提交问题:https://github.com/obra/superpowers/issues
- 主文档:https://github.com/obra/superpowers
- OpenCode 文档:https://opencode.ai/docs/
