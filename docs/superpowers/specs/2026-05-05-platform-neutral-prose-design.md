> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 平台中立文案 —— Phase A 设计

## 背景

Superpowers 会发布到多个 agent 运行时(Claude Code、Codex、Cursor、OpenCode、Copilot CLI、Gemini CLI)。技能内容与配套文档最初是为 Claude Code 编写的,在适用于任何运行时 agent 的地方也写成了 "Claude"。OpenAI 的内部 fork(openai/plugins#217)曾尝试整体重写,结果多处改得明显有错——重写了历史归因路径、模型名称和平台相关的安装说明——我们希望在避免这一错误的同时,把那些确实只是附带提法的平台中心化文案清理掉。

整个工作按引用类别分成多个阶段。**本规范只覆盖 Phase A:**在非平台特定语境下提及 "Claude" 的泛化第三人称文案。后续阶段(配置文件引用、宣传文案、工具名引用)不在本篇范围内,会另有规范。

## 范围内

以下位置中泛化文案里对 "Claude" 的提及:

- `skills/*/SKILL.md` 以及活跃技能目录中的配套 `.md` 文件
- `skills/writing-skills/anthropic-best-practices.md`
- `README.md`(仅限泛化文案的提及,不含平台宣传)

外加一个造词改名:**Claude Search Optimization(CSO)→ Skill Discovery Optimization(SDO)**,位于 `skills/writing-skills/SKILL.md`。

## 范围外

- **平台/运行时陈述** —— "In Claude Code:"、安装说明、工具映射引用。(Phase D 候选。)
- **配置文件引用** —— CLAUDE.md、AGENTS.md、GEMINI.md 优先级列表,以及"项目约定放哪里"的提示。(Phase B。)
- **工具名引用** —— `Skill`、`Bash`、`Read`、`Task`、`TodoWrite`。技能是以 Claude Code 的工具词汇编写的,现有的 `references/{codex,copilot,gemini}-tools.md` 文件负责映射它们。(撰写本规范时,计划是推迟或跳过这些;Phase E 最终完成了——在活跃技能中用动作语言替换工具名,并把平台工具 refs 统一到同一套词汇。)
- **README 中的宣传文案** —— "Superpowers for Claude Code"、以平台命名的安装章节。(Phase C。)
- **历史产物** —— `docs/plans/*.md`、`docs/superpowers/specs/*.md`、`CREATION-LOG.md`。这些是带日期的时间点文档,重写它们等于改写历史。
- **模型标识符** —— Claude Haiku / Sonnet / Opus。这些是真实的产品名。
- **文件名 / URL 引用** —— `CLAUDE.md`、`claude.com`、`claude-plugin/`、`~/.claude/` 下的路径。
- **`anthropic-best-practices.md` 文件名** —— 该文件仍以来源命名,尽管其中的正文会被重写。

## 替换风格

使用在英文中读起来自然的混合风格:

- **第二人称 —— "your agent"**:当对技能作者谈*他们*的运行时时
  - "your agent reads the description"
- **第三人称 —— "the agent" / "agents" / "an agent"**:当泛化描述系统行为时
  - "Future agents find your skills"
  - "Use words an agent would search for"
  - "Agents read SKILL.md only when the skill becomes relevant"

选贴合上下文句子的一种;不要为强行一致而拗口。在自然的地方用复数("future agents"、"agents read"),而不是总说 "the agent"。

### 保留为 "Claude" 的例外

- 模型名:Claude Haiku、Claude Sonnet、Claude Opus
- 文件名和 URL:`CLAUDE.md`、`claude.com`、`~/.claude/`
- 品牌平台名 "Claude Code",凡是明确指该运行时本身时(后续阶段处理)

### 造词改名

- **Claude Search Optimization(CSO)→ Skill Discovery Optimization(SDO)**
  - 出现在 `skills/writing-skills/SKILL.md` 的一个章节标题及附近文案中。改掉标题、缩写以及文件内的所有交叉引用。

## 受影响文件

基于一次过滤掉例外情况的 `grep` 得到的近似统计:

| 文件 | 泛化文案提及数 |
|------|------------------------|
| `skills/writing-skills/SKILL.md` | ~12(含 CSO 标题及正文) |
| `skills/writing-skills/anthropic-best-practices.md` | ~30 |
| `skills/writing-skills/examples/CLAUDE_MD_TESTING.md` | ~1 —— 文件名保留(它是一个 CLAUDE.md 测试产物);"Variant C: Claude.AI Emphatic Style" 标题也保留(它是命名某种具体风格的标签) |
| `README.md` | ~1 |

最终清单在实现过程中通过重新运行过滤后的 grep 确认。

## 提交计划

四个原子提交,按顺序:

1. **在 `skills/writing-skills/SKILL.md` 中把 CSO 改名为 SDO**。机械、独立,若我们对这个术语改主意也容易回滚。
2. **活跃技能文案** —— 在 `skills/*/SKILL.md` 与配套 `.md` 中把泛化的 "Claude" 替换为 "agent" 形式,`anthropic-best-practices.md` 除外。
3. **`anthropic-best-practices.md` 文案** —— 同样的替换规则。单独提交是因为该文件是对外部文档的内部改编;隔离改动能让将来与上游对账更易读。
4. **README.md 文案** *(仅在过滤后仍有泛化文案提及时)*。若无则跳过。

每条提交信息注明阶段("Phase A")与切片("rename CSO to SDO"、"agent prose in active skills" 等),让整个提交系列自解释。

## 验证

每个提交之后:

- `grep -rn "Claude" <touched-paths>` —— 每个剩余命中都必须落入已记录的例外(模型名、文件名、URL、"Claude Code" 平台名、历史产物)。
- 通读被改文件 —— 替换不应破坏句子流畅性、代词一致性或列表的并列结构。
- 无需运行测试;这是纯文案改动。

最后一个提交之后:

- 在真实会话中快速浏览每个被修改的技能,确认没有读起来别扭的地方。

## 非目标

- 不改行为、结构、标题(CSO→SDO 除外)、示例、代码块或 YAML frontmatter。
- 不新增章节、提示框或兼容性说明。
- 编辑时不做替换之外的"改进"。
