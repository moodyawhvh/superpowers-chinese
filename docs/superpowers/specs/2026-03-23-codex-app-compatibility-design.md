> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# Codex App 兼容性:Worktree 与收尾技能适配

让 superpowers 技能在 Codex App 的沙箱化 worktree 环境中正常工作,同时不破坏 Claude Code 或 Codex CLI 的既有行为。

**工单:** PRI-823

## 动机

Codex App 在它自己管理的 git worktree 中运行代理——detached HEAD,位于 `$CODEX_HOME/worktrees/` 下,并有 Seatbelt 沙箱阻止 `git checkout -b`、`git push` 和网络访问。三个 superpowers 技能都假定 git 访问不受限:`using-git-worktrees` 会创建带命名分支的手动 worktree,`finishing-a-development-branch` 按分支名执行合并/推送/PR,而 `subagent-driven-development` 两者都依赖。

Codex CLI(开源终端工具)没有这一冲突——它没有内置的 worktree 管理。我们的手动 worktree 方案在那里正好填补隔离空缺。问题只出在 Codex App 上。

## 实测发现

2026-03-23 在 Codex App 中实测:

| 操作 | workspace-write 沙箱 | 完全访问沙箱 |
|---|---|---|
| `git add` | 可用 | 可用 |
| `git commit` | 可用 | 可用 |
| `git checkout -b` | **被阻止**(无法写 `.git/refs/heads/`) | 可用 |
| `git push` | **被阻止**(网络 + `.git/refs/remotes/`) | 可用 |
| `gh pr create` | **被阻止**(网络) | 可用 |
| `git status/diff/log` | 可用 | 可用 |

其他发现:
- `spawn_agent` 子代理**共享**父线程的文件系统(经标记文件测试确认)
- 无论 worktree 从哪个分支启动,App 标题栏都会出现 "Create branch" 按钮
- App 原生收尾流程:Create branch → Commit 弹窗 → Commit and push / Commit and create PR
- `network_access = true` 配置在 macOS 上静默失效(issue #10390)

## 设计:只读环境检测

三条只读 git 命令即可无副作用地检测环境:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

由此推导出两个信号:

- **IN_LINKED_WORKTREE:** `GIT_DIR != GIT_COMMON`——代理正处于由其他东西创建的 worktree 中(Codex App、Claude Code Agent 工具、之前的技能运行,或用户本人)
- **ON_DETACHED_HEAD:** `BRANCH` 为空——不存在命名分支

为什么用 `git-dir != git-common-dir` 而不检查 `show-toplevel`:
- 普通仓库中,二者都解析到同一个 `.git` 目录
- 链接 worktree 中,`git-dir` 是 `.git/worktrees/<name>`,而 `git-common-dir` 是 `.git`
- 子模块中二者相等——避免了 `show-toplevel` 会产生的误报
- 通过 `cd && pwd -P` 解析可处理相对路径问题(`git-common-dir` 在普通仓库中返回相对的 `.git`,在 worktree 中返回绝对路径)和符号链接(macOS 的 `/tmp` → `/private/tmp`)

### 决策矩阵

| 链接 worktree? | Detached HEAD? | 环境 | 动作 |
|---|---|---|---|
| 否 | 否 | Claude Code / Codex CLI / 普通 git | 完整技能行为(不变) |
| 是 | 是 | Codex App worktree(workspace-write) | 跳过 worktree 创建;收尾时交付交接信息 |
| 是 | 否 | Codex App(完全访问)或手动 worktree | 跳过 worktree 创建;完整收尾流程 |
| 否 | 是 | 少见情况(手动 detached HEAD) | 正常创建 worktree;收尾时告警 |

## 改动

### 1. `using-git-worktrees/SKILL.md` — 新增 Step 0(约 12 行)

在 "Overview" 与 "Directory Selection Process" 之间新增一节:

**Step 0:检查是否已处于隔离工作区**

运行检测命令。若 `GIT_DIR != GIT_COMMON`,则完全跳过 worktree 创建,改为:
1. 直接跳到 Creation Steps 下的 "Run Project Setup" 小节——`npm install` 等命令是幂等的,为稳妥起见值得运行
2. 然后是 "Verify Clean Baseline"——运行测试
3. 携带分支状态进行汇报:
   - 在分支上:"已处于 `<path>` 的隔离工作区,分支 `<name>`。测试通过。可以开始实现。"
   - Detached HEAD:"已处于 `<path>` 的隔离工作区(detached HEAD,由外部管理)。测试通过。注意:收尾时需要创建分支。可以开始实现。"

若 `GIT_DIR == GIT_COMMON`,则照常走完整的 worktree 创建流程(不变)。

Step 0 生效时跳过安全验证(.gitignore 检查)——对外部创建的 worktree 而言该项无关紧要。

更新 Integration 小节的 "Called by" 条目。把每条的描述从各自的上下文文本统一改为:"Ensures isolated workspace (creates one or verifies existing)"。例如,`subagent-driven-development` 条目从 "REQUIRED: Set up isolated workspace before starting" 改为 "REQUIRED: Ensures isolated workspace (creates one or verifies existing)"。

**沙箱回退:** 若 `GIT_DIR == GIT_COMMON` 且技能已进入 Creation Steps,但 `git worktree add -b` 因权限错误失败(例如 Seatbelt 沙箱拒绝),则视为迟发现的受限环境。回退到 Step 0 的"已处于工作区"行为——跳过创建,在当前目录运行 setup 与基线测试,并相应汇报。

在 Step 0 汇报之后即停止。不要继续进入 Directory Selection 或 Creation Steps。

**其余一切不变:** Directory Selection、Safety Verification、Creation Steps、Project Setup、Baseline Tests、Quick Reference、Common Mistakes、Red Flags。

### 2. `finishing-a-development-branch/SKILL.md` — 新增 Step 1.5 + 清理护栏(约 20 行)

**Step 1.5:检测环境**(位于 Step 1 "Verify Tests" 之后、Step 2 "Determine Base Branch" 之前)

运行检测命令。共三条路径:

- **路径 A** 完全跳过 Step 2 和 Step 3(无需 base 分支或选项)。
- **路径 B 和 C** 照常经过 Step 2(确定 base 分支)和 Step 3(呈现选项)。

**路径 A —— 外部管理的 worktree + detached HEAD**(`GIT_DIR != GIT_COMMON` 且 `BRANCH` 为空):

首先,确保所有工作已暂存并提交(`git add` + `git commit`)。Codex App 的收尾控件只作用于已提交的工作。

然后向用户呈现以下内容(不要呈现 4 选项菜单):

```
Implementation complete. All tests passing.
Current HEAD: <full-commit-sha>

This workspace is externally managed (detached HEAD).
I cannot create branches, push, or open PRs from here.

⚠ These commits are on a detached HEAD. If you do not create a branch,
they may be lost when this workspace is cleaned up.

If your host application provides these controls:
- "Create branch" — to name a branch, then commit/push/PR
- "Hand off to local" — to move changes to your local checkout

Suggested branch name: <ticket-id/short-description>
Suggested commit message: <summary-of-work>
```

分支名推导:如有工单 ID 则使用(如 `pri-823/codex-compat`),否则把计划标题的前 5 个词转成 slug,否则省略该建议。分支名中避免包含敏感内容(漏洞描述、客户名称)。

直接跳到 Step 5(对外部管理的 worktree,清理是空操作)。

**路径 B —— 外部管理的 worktree + 命名分支**(`GIT_DIR != GIT_COMMON` 且 `BRANCH` 存在):

照常呈现 4 选项菜单。(Step 5 清理护栏会独立地重新检测外部管理状态。)

**路径 C —— 正常环境**(`GIT_DIR == GIT_COMMON`):

照今天一样呈现 4 选项菜单(不变)。

**Step 5 清理护栏:**

清理时重新运行 `GIT_DIR` 与 `GIT_COMMON` 的比对检测(不要依赖技能早前的输出——收尾技能可能运行在另一个会话中)。若 `GIT_DIR != GIT_COMMON`,则跳过 `git worktree remove`——该工作区归宿主环境所有。

否则照今天一样检查并移除。注意:现有 Step 5 文本写的是 "For Options 1, 2, 4",而 Quick Reference 表和 Common Mistakes 小节写的是 "Options 1 & 4 only."。新护栏加在这段既有逻辑之前,不改变哪些选项会触发清理。

**其余一切不变:** Options 1-4 逻辑、Quick Reference、Common Mistakes、Red Flags。

### 3. `subagent-driven-development/SKILL.md` 与 `executing-plans/SKILL.md` — 各改 1 行

两个技能的 Integration 小节中有一行完全相同。从:

```
- superpowers:using-git-worktrees - REQUIRED: Set up isolated workspace before starting
```

改为:

```
- superpowers:using-git-worktrees - REQUIRED: Ensures isolated workspace (creates one or verifies existing)
```

**其余一切不变:** 派发/评审循环、提示词模板、模型选择、状态处理、red flags。

### 4. `codex-tools.md` — 新增环境检测文档(约 15 行)

在文末新增两节:

**Environment Detection(环境检测):**

```markdown
## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

\```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
\```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1.5 for how each skill uses these signals.
```

**Codex App Finishing(Codex App 收尾):**

```markdown
## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.
```

## 不变之处

- `implementer-prompt.md`、`spec-reviewer-prompt.md`、`code-quality-reviewer-prompt.md`——子代理提示词不动
- `executing-plans/SKILL.md`——仅 Integration 描述改 1 行(与 `subagent-driven-development` 相同);所有运行时行为不变
- `dispatching-parallel-agents/SKILL.md`——不涉及 worktree 或收尾操作
- `.codex/INSTALL.md`——安装流程不变
- 4 选项收尾菜单——对 Claude Code 和 Codex CLI 原样保留
- 完整 worktree 创建流程——对非 worktree 环境原样保留
- 子代理派发/评审/迭代循环——不变(文件系统共享已确认)

## 范围汇总

| 文件 | 改动 |
|---|---|
| `skills/using-git-worktrees/SKILL.md` | +12 行(Step 0) |
| `skills/finishing-a-development-branch/SKILL.md` | +20 行(Step 1.5 + 清理护栏) |
| `skills/subagent-driven-development/SKILL.md` | 改 1 行 |
| `skills/executing-plans/SKILL.md` | 改 1 行 |
| `skills/using-superpowers/references/codex-tools.md` | +15 行 |

5 个文件共新增/修改约 50 行。零新文件。零破坏性变更。

## 后续考虑

若第三个技能需要同样的检测模式,就把它提取到共享的 `references/environment-detection.md` 文件中(方案 B)。现在不需要——目前只有 2 个技能用到。

## 测试计划

### 自动化(实现后在 Claude Code 中运行)

1. 普通仓库检测——断言 IN_LINKED_WORKTREE=false
2. 链接 worktree 检测——用 `git worktree add` 创建测试 worktree,断言 IN_LINKED_WORKTREE=true
3. Detached HEAD 检测——`git checkout --detach`,断言 ON_DETACHED_HEAD=true
4. 收尾技能交接输出——在受限环境中验证呈现的是交接信息(而非 4 选项菜单)
5. **Step 5 清理护栏**——创建链接 worktree(`git worktree add /tmp/test-cleanup -b test-cleanup`),`cd` 进入其中,运行 Step 5 清理检测(`GIT_DIR` 与 `GIT_COMMON` 比对),断言它不会调用 `git worktree remove`。然后 `cd` 回主仓库,运行同样的检测,断言它会调用 `git worktree remove`。测试完成后清理该测试 worktree。

### Codex App 手动测试(5 项)

1. Worktree 线程中的检测(workspace-write)——验证 GIT_DIR != GIT_COMMON、分支为空
2. Worktree 线程中的检测(完全访问)——同样的检测,不同的沙箱行为
3. 收尾技能交接格式——验证代理输出的是交接信息,而非 4 选项菜单
4. 完整生命周期——检测 → 提交 → 收尾检测 → 正确行为 → 清理
5. **Local 线程中的沙箱回退**——启动一个 Codex App **Local 线程**(workspace-write 沙箱)。提示词:"Use the superpowers skill `using-git-worktrees` to set up an isolated workspace for implementing a small change."。预检:`git checkout -b test-sandbox-check` 应以 `Operation not permitted` 失败。预期:技能检测到 `GIT_DIR == GIT_COMMON`(普通仓库),尝试 `git worktree add -b`,撞上 Seatbelt 拒绝,回退到 Step 0 的"已处于工作区"行为——运行 setup 与基线测试,并从当前目录汇报就绪。通过标准:代理优雅恢复,没有晦涩的报错。失败标准:代理打印原始 Seatbelt 错误、反复重试,或以混乱输出放弃。

### 回归

- 既有 Claude Code 技能触发测试仍然通过
- 既有 subagent-driven-development 集成测试仍然通过
- 正常 Claude Code 会话:完整 worktree 创建 + 4 选项收尾仍然可用
