> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# Kimi Code 的 Superpowers

在 [Kimi Code](https://github.com/MoonshotAI/kimi-code) 中使用 Superpowers 的完整指南。

## 安装

Superpowers 已上架 Kimi Code 的插件市场。

打开插件管理器:

```text
/plugins
```

进入 `Marketplace` > `Superpowers` 并安装。

也可以直接从本仓库安装:

```text
/plugins install https://github.com/obra/superpowers
```

若要在正式发布前基于 `dev` 分支做验证,请显式指定分支:

```text
/plugins install https://github.com/obra/superpowers/tree/dev
```

Kimi Code 只在新会话中应用插件变更。安装、更新、启用、禁用或重载插件之后,请用 `/new` 开启新会话。

## 工作原理

Kimi 插件的清单文件位于 `.kimi-plugin/plugin.json`。

这个清单做三件事:

1. 让 Kimi Code 指向现有的 `skills/` 目录。
2. 通过 `sessionStart.skill` 在会话开始时加载 `using-superpowers`。
3. 通过 `skillInstructions` 提供 Kimi 专属的工具映射。

Kimi Code 直接从本仓库读取 Superpowers 技能,没有复制的技能、符号链接、hook,也没有额外的运行时依赖。

## 工具映射

技能以动作来描述,而不是硬编码某个运行时的工具名。在 Kimi Code 中,这些动作解析为:

- "询问用户" / "提出澄清问题" -> `AskUserQuestion`
- "创建 todo" / "在 todo 列表中标记完成" -> `TodoList`
- "派发子代理" -> `Agent`
- "调用技能" -> Kimi Code 原生的 `Skill` 工具
- "读取文件" / "写入文件" / "编辑文件" -> `Read`、`Write`、`Edit`
- "运行 shell 命令" -> `Bash`
- "搜索文件内容" -> `Grep`
- "按路径或模式查找文件" -> `Glob`
- "抓取 URL" -> `FetchURL`
- "搜索网络" -> `WebSearch`

## 更新

使用 Kimi Code 的插件管理器:

```text
/plugins
```

选中 Superpowers 并在其中执行更新。更新完成后用 `/new` 开启新会话。

## 故障排查

### 插件未加载

1. 运行 `/plugins info superpowers` 并查看诊断信息。
2. 确认插件已启用。
3. 安装或更新后,用 `/new` 开启新会话。

### 从 GitHub 直接安装时装到了旧版本

对于裸仓库 URL,只要存在 GitHub release,Kimi Code 就会安装最新的 release。要在 Superpowers 发布前测试未发布的改动,请显式安装分支:

```text
/plugins install https://github.com/obra/superpowers/tree/dev
```

### 技能未触发

1. 确认 `/plugins info superpowers` 显示插件已启用。
2. 用 `/new` 开启新会话。
3. 试试这条验收提示词:`Let's make a react todo list`。安装正常时,应当在写代码之前先加载 `brainstorming`。
