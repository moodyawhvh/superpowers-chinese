> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 为 OpenCode 安装 Superpowers

## 前置条件

- 已安装 [OpenCode.ai](https://opencode.ai)

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

## 从旧的符号链接安装方式迁移

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

使用 OpenCode 原生的 `skill` 工具:

```
use skill tool to list skills
use skill tool to load brainstorming
```

## 更新

OpenCode 通过基于 git 的包规格安装 Superpowers。某些版本的 OpenCode 和 Bun 会把解析出的 git 依赖固定在 lockfile 或缓存中,导致重启后拿不到最新的 Superpowers 提交。如果看不到更新,请清理 OpenCode 的包缓存或重新安装插件。

要固定某个版本:

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git#v5.0.3"]
}
```

## 故障排查

### 插件未加载

1. 查看日志:`opencode run --print-logs "hello" 2>&1 | grep -i superpowers`
2. 检查 `opencode.json` 中的插件配置行
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

1. 使用 `skill` 工具列出发现的技能
2. 检查插件是否正常加载(见上文)

### 工具映射

技能用动作来描述("创建一个 todo"、"派发一个子代理"、"读取一个文件")。在 OpenCode 上,它们解析为:

- "创建 todo" / "在 todo 列表中标记完成" → `todowrite`
- `Subagent (general-purpose):` 模板 → `task` 工具,`subagent_type: "general"`(代码库探索用 `"explore"`)
- "调用技能" → OpenCode 原生的 `skill` 工具
- "读取文件" → `read`
- "创建文件" / "编辑文件" / "删除文件" → `apply_patch`
- "运行 shell 命令" → `bash`
- "搜索文件内容" / "按名称查找文件" → `grep`、`glob`
- "抓取 URL" → `webfetch`

## 获取帮助

- 提交问题:https://github.com/obra/superpowers/issues
- 完整文档:https://github.com/obra/superpowers/blob/main/docs/README.opencode.md
