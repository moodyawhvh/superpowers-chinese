> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# Superpowers 测试

Superpowers 有两类不同的测试,各自位于独立目录:

- **`tests/`** — 插件的非 LLM 代码是否正常工作?基于 Bash + node + python 的集成测试,覆盖 brainstorm-server JS、OpenCode 插件加载、codex-plugin 同步以及分析工具。
- **`evals/`** — agent 在真实 LLM 会话中的行为是否正确?Python harness 驱动 Claude Code / Codex / Gemini CLI 的真实 tmux 会话,由 LLM actor 和 verifier 判定技能遵循情况。

## 插件测试

位于 `tests/`。目前包括:

- `tests/brainstorm-server/` — brainstorm server JS 代码的 node 测试套件。
- `tests/opencode/` — 针对 OpenCode 插件加载、引导缓存和工具注册的 bash 测试。
- `tests/codex-plugin-sync/` — bash 同步校验。
- `tests/kimi/` — 针对 Kimi 插件清单接线的 bash/Python 检查。
- `tests/claude-code/test-helpers.sh`、`analyze-token-usage.py` — 其余 bash 测试使用的工具。
- `tests/claude-code/test-subagent-driven-development.sh` — agent 能否描述 SDD 的测试(drill 中无对应项;测的是描述记忆能力,不是行为)。
- `tests/claude-code/test-subagent-driven-development-integration.sh` — 带令牌分析的扩展 SDD 集成测试(drill 只覆盖 YAGNI 子集;bash 版还增加了提交次数、Claude Code 任务跟踪和令牌遥测断言)。
- `tests/claude-code/test-worktree-native-preference.sh` — worktree 技能的 RED-GREEN-REFACTOR 验证(drill 覆盖 PRESSURE 阶段;bash 版还覆盖 RED/GREEN 基线)。
- `tests/explicit-skill-requests/` — drill 未覆盖的 Haiku 专属、多轮对话以及按名称提示技能的测试。

通过相关目录下的 `run-*.sh` 或 `npm test` 运行插件测试。

## 技能行为评估

位于 `evals/`。Drill 是测试 harness,场景文件位于 `evals/scenarios/*.yaml`。环境配置见 `evals/README.md`。快速开始:

```bash
cd evals
uv sync --extra dev
export ANTHROPIC_API_KEY=sk-...
uv run drill run triggering-test-driven-development -b claude
```

Drill 场景运行很慢(每个 3-30+ 分钟),并且会跑真实的 LLM 会话。目前尚未纳入 CI;自然的后续方向是建立分层机制(PR 时跑快速子集,夜间和按需跑全量)。
