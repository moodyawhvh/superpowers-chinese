> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 平台中立的配置文件引用 —— Phase B 设计

## 背景

Phase A(见 `2026-05-05-platform-neutral-prose-design.md`)把泛指第三人称的 "Claude" 行文替换成了 agent 中立的形式。本阶段处理下一类:skills 中对各家平台专属指令文件(CLAUDE.md、AGENTS.md、GEMINI.md)的引用。

这个插件运行在多个宿主(harness)上,而每个宿主读取自己的指令文件。当某个 skill 把 CLAUDE.md 说成是唯一的文件时,这是一种以 Claude-Code 为中心的假设,在 Codex / Gemini CLI / OpenCode 上并不成立。

## 范围内

生效 skills 中的两处具体行:

1. **`skills/writing-skills/SKILL.md:58`** —— `Project-specific conventions (put in CLAUDE.md)`
2. **`skills/receiving-code-review/SKILL.md:30`** —— `"You're absolutely right!" (explicit CLAUDE.md violation)`

## 范围外

- **`skills/using-superpowers/SKILL.md:22, 26`** —— 指令优先级列表。该列表已经以包容的方式同时点名三者(CLAUDE.md、GEMINI.md、AGENTS.md),这是正确的:这一节确实在陈述多平台插件上"什么算作用户指令"。无需改动。
- **历史 / 示例产物**:
  - `skills/systematic-debugging/CREATION-LOG.md` —— 归属路径(`~/.claude/CLAUDE.md`)是历史事实。
  - `skills/writing-skills/examples/CLAUDE_MD_TESTING.md` —— 整个文件就是一个测试 CLAUDE.md 内容变体的完整示例。文件名、正文以及来自 `testing-skills-with-subagents.md` 的引用都保持不变;把它们规范化会毁掉这个示例。
- **平台工具引用** —— Phase D 候选:
  - `skills/using-superpowers/SKILL.md:40`(关于 GEMINI.md 的 Gemini CLI 工具映射说明)
  - `skills/using-superpowers/references/gemini-tools.md`(`save_memory` 持久化到 GEMINI.md)

## 替换规则

两次不同的替换,各对应一行范围内内容。

### 规则 1:"项目特定约定放在哪里"

`writing-skills/SKILL.md:58`:

- **改前:** `Project-specific conventions (put in CLAUDE.md)`
- **改后:** `Project-specific conventions (put in your instructions file)`

使用通用表述,而不是选定某个文件名。不同宿主读取不同的文件(CLAUDE.md、AGENTS.md、GEMINI.md 等),skill 不应假定其中某一个。平台工具参考文档(`references/{codex,copilot,gemini}-tools.md`)才是点名各平台首选文件的正确位置。

### 规则 2:"(explicit CLAUDE.md violation)" 括注

`receiving-code-review/SKILL.md:30`:

- **改前:** `"You're absolutely right!" (explicit CLAUDE.md violation)`
- **改后:** `"You're absolutely right!" (explicit instruction-file violation)`

这个括注承担着实际功能 —— 它表明这个说法不只是风格糟糕,而是实实在在地违反了许多用户写进指令文件的规则。"instruction file"(指令文件)是能一并涵盖 AGENTS.md / CLAUDE.md / GEMINI.md 的自然跨平台术语,既保留了原有的信号强度,又不点名某个文件名,也不会弱化成 "common"(常见)。

## 提交计划

按顺序的原子提交:

1. **`writing-skills/SKILL.md`** —— 在"项目约定放在哪里"一行中把 CLAUDE.md 改为 "your instructions file"
2. **`receiving-code-review/SKILL.md`** —— 在违规括注中把 CLAUDE.md 改为 instruction-file
3. **平台工具参考文档** —— 在每份 `references/{codex,copilot,gemini}-tools.md` 中加入各平台首选的指令文件名(CLAUDE.md、AGENTS.md、GEMINI.md 等),让读者能把 "your instructions file" 对应到真实文件名。

每条提交信息注明 "Phase B" 和对应的切片。

## 验证

每次提交后:

- 阅读周围段落,确认语法和含义依然通顺。
- `grep -n "CLAUDE\.md" <touched-file>` —— 生效行文中不应再有命中(豁免项已有记录)。

两次提交都完成后:

- `grep -rn "CLAUDE\.md" skills/` 应只返回已记录的豁免项(CREATION-LOG、CLAUDE_MD_TESTING 及指向它的引用、using-superpowers 中的优先级列表)。

## 非目标

- 不要动 `using-superpowers/SKILL.md` 中优先级列表的顺序。调整 CLAUDE.md / GEMINI.md / AGENTS.md 的顺序只是审美改动,不属于替换,不在本阶段范围内。
- 不要重命名 `examples/CLAUDE_MD_TESTING.md`,也不要改动其内容。
- 不要修改 Gemini-CLI 专属的工具引用(Phase D 候选)。

## 实现说明

本文所写的 Phase B 覆盖三个提交和三份非 Claude-Code 平台工具参考。实际实现更进一步:出于对称性考虑,第四份参考 `references/claude-code-tools.md` 在提交 `8505703` 中补齐,让 Claude Code 的指令文件约定和工具名列表与其他平台并列,而不是隐含在周围的 skill 行文里。这一补充未在本规格的预料之中,但与其意图一致。
