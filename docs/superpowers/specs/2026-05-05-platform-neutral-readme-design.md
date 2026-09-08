> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 平台中立的 README 排序 —— Phase C 设计

## 背景

Phase A 与 Phase B(见 `2026-05-05-platform-neutral-prose-design.md` 和 `2026-05-05-platform-neutral-config-refs-design.md`)已经中和了 README 中泛指 Claude 的行文和配置文件引用。剩下带有平台倾向的信号是排版:README 的两处平台列表把 Claude Code 排在第一位,其余部分也没有严格按字母排序。

本阶段修复排序问题。不改动任何行文。

## 范围内

1. **Quickstart 平台列表**(`README.md:7`)—— 受支持宿主(harness)的内联链接列表
2. **安装章节排序**(`README.md:35–152`)—— 各宿主的安装子章节

## 范围外

- 行文、marketplace 名称、插件 ID、URL —— 现状在事实上全部正确。
- Claude Code 章节的视觉权重(它包含两个子章节 —— Anthropic 官方 marketplace 和 Superpowers marketplace)。两者都是真实存在的安装路径;合并它们会掩盖准确信息。
- 各安装块内部的章节标题与内容 —— 只改变块的排序。

## 替换方案

两处列表都重排为严格字母序:

| 原顺序 | 新顺序 |
|--------|--------|
| Claude Code | Claude Code |
| Codex CLI | Codex App |
| Codex App | Codex CLI |
| Factory Droid | Cursor |
| Gemini CLI | Factory Droid |
| OpenCode | Gemini CLI |
| Cursor | GitHub Copilot CLI |
| GitHub Copilot CLI | OpenCode |

共三次移动:Codex App 与 Codex CLI 互换;Cursor 上移两位;GitHub Copilot CLI 上移一位。

Claude Code 纯属字母排序的巧合才保持第一(`Cl…` 排在 `Co…` 之前)。

## 提交计划

用一个原子提交同时覆盖两处列表,因为只改其中一处会造成 quickstart 与安装章节之间的不一致。

## 验证

- Quickstart 锚点(`#claude-code`、`#codex-app` 等)仍能解析到现有的 `### …` 标题 —— 没有任何标题被重命名。
- 每个安装子章节的正文在改动前后逐字节一致;只有位置发生变化。
- `git diff README.md` 只显示章节移动,没有内容编辑。
