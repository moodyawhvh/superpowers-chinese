<div align="center">

# superpowers 中文文档

[![原项目](https://img.shields.io/badge/原项目-obra--superpowers-blue?style=flat-square&logo=github)](https://github.com/obra/superpowers)
[![GitHub Stars](https://img.shields.io/github/stars/obra/superpowers?style=flat-square&label=原项目Stars)](https://github.com/obra/superpowers/stargazers)
[![微信联系](https://img.shields.io/badge/微信-uaycar-brightgreen?style=flat-square&logo=wechat)](#)

</div>

> 本文档是 [obra/superpowers](https://github.com/obra/superpowers) 官方 README 的完整中文翻译。完整源代码请访问原项目:https://github.com/obra/superpowers

---

Superpowers 是一套为你的 AI 编程代理打造的完整软件开发方法论,构建在一组可组合的技能(skills)和若干启动指令之上,确保代理真正用起来这些技能。

## 目录

- [工作原理](#工作原理)
- [商业服务](#商业服务)
- [安装](#安装)
  - [Claude Code](#claude-code)
  - [Antigravity](#antigravity)
  - [Codex 桌面版](#codex-桌面版)
  - [Codex CLI](#codex-cli)
  - [Cursor](#cursor)
  - [Devin CLI](#devin-cli)
  - [Factory Droid](#factory-droid)
  - [Gemini CLI](#gemini-cli)
  - [GitHub Copilot CLI](#github-copilot-cli)
  - [Grok Build CLI](#grok-build-cli)
  - [Kimi Code](#kimi-code)
  - [OpenCode](#opencode)
  - [Pi](#pi)
  - [Hermes Agent](#hermes-agent)
- [基本工作流](#基本工作流)
- [社区](#社区)
- [包含哪些内容](#包含哪些内容)
- [设计哲学](#设计哲学)
- [参与贡献](#参与贡献)
- [更新](#更新)
- [许可证](#许可证)
- [可视化伴侣遥测](#可视化伴侣遥测)

## 工作原理

一切从你启动编码代理的那一刻开始。一旦它发现你要构建某个东西,它**不会**直接扑上去写代码,而是先退一步,问清楚你真正想做的是什么。

当它从对话中打磨出一份规格说明后,会把设计分成足够短的块展示给你,让你真正读得进去、消化得了。

在你确认设计之后,你的代理会制定一份实现计划——这份计划要清晰到连一个热情有余、品味欠佳、毫无判断力、不了解项目背景、还讨厌写测试的初级工程师都能照着执行。它强调真正的红/绿 TDD(测试驱动开发)、YAGNI(你不会需要它)和 DRY(不要重复自己)。

接下来,当你说"开工"之后,它会启动**子代理驱动开发**流程:让各个代理逐个完成工程任务,检查和评审它们的产出,然后继续推进。你的代理按你一起敲定的计划自主连续工作一两个小时而不跑偏,是再正常不过的事。

这套系统还有更多细节,但这就是核心。而且由于技能是自动触发的,你不需要做任何特殊操作。你的编码代理就那样拥有了 Superpowers(超能力)。

## 商业服务

如果你在企业环境中使用 Superpowers,需要商业支持、额外工具或托管服务,欢迎发邮件联系:sales@primeradiant.com。

## 安装

不同宿主环境(harness)的安装方式不同。如果你同时使用多个环境,需要在每个环境中分别安装。

### Claude Code

Superpowers 已上架 [Claude 官方插件市场](https://claude.com/plugins/superpowers)。

#### 官方市场

- 从 Anthropic 官方市场安装插件:

  ```bash
  /plugin install superpowers@claude-plugins-official
  ```

#### Superpowers 市场

Superpowers 市场为 Claude Code 提供 Superpowers 及其他一些相关插件。

- 添加市场:

  ```bash
  /plugin marketplace add obra/superpowers-marketplace
  ```

- 从该市场安装插件:

  ```bash
  /plugin install superpowers@superpowers-marketplace
  ```

### Antigravity

以插件形式从本仓库安装:

```bash
agy plugin install https://github.com/obra/superpowers
```

Antigravity 会运行插件的会话启动钩子,因此从第一条消息起 Superpowers 即已生效。重新执行同一条命令即可更新。

### Codex 桌面版

Superpowers 已上架 [Codex 官方插件市场](https://github.com/openai/plugins)。

- 在 Codex 应用中,点击侧边栏的 Plugins。
- 你应该在 Coding 分区看到 `Superpowers`。
- 点击 Superpowers 旁边的 `+`,按提示完成安装。

### Codex CLI

Superpowers 已上架 [Codex 官方插件市场](https://github.com/openai/plugins)。

- 打开插件搜索界面:

  ```bash
  /plugins
  ```

- 搜索 Superpowers:

  ```bash
  superpowers
  ```

- 选择 `Install Plugin`。

### Cursor

- 在 Cursor Agent 聊天中,从市场安装:

  ```text
  /add-plugin superpowers
  ```

- 或者在插件市场里搜索 "superpowers"。

### Devin CLI

- 从本仓库安装插件:

  ```bash
  devin plugins install obra/superpowers
  ```

- 之后用以下命令更新到最新版:

  ```bash
  devin plugins update superpowers
  ```

### Factory Droid

- 添加市场:

  ```bash
  droid plugin marketplace add https://github.com/obra/superpowers
  ```

- 安装插件:

  ```bash
  droid plugin install superpowers@superpowers
  ```

### Gemini CLI

- 安装扩展:

  ```bash
  gemini extensions install https://github.com/obra/superpowers
  ```

- 之后更新:

  ```bash
  gemini extensions update superpowers
  ```

### GitHub Copilot CLI

- 添加市场:

  ```bash
  copilot plugin marketplace add obra/superpowers-marketplace
  ```

- 安装插件:

  ```bash
  copilot plugin install superpowers@superpowers-marketplace
  ```

### Grok Build CLI

Superpowers 已上架 [Grok 官方插件市场](https://github.com/xai-org/plugin-marketplace)。

- 从 xAI 官方市场安装插件:

  ```bash
  grok plugin install superpowers@xai-official --trust
  ```

- 或者在 TUI 中打开市场,搜索 Superpowers 并安装:

  ```text
  /marketplace
  ```

### Kimi Code

Superpowers 已上架 Kimi Code 的插件市场。

- 打开 Kimi Code 的插件管理器:

  ```text
  /plugins
  ```

- 进入 `Marketplace` > `Superpowers` 并安装。

- 或者直接从本仓库安装:

  ```text
  /plugins install https://github.com/obra/superpowers
  ```

- 详细文档:[docs/README.kimi.md](https://github.com/obra/superpowers/blob/main/docs/README.kimi.md)

### OpenCode

OpenCode 使用自己的插件安装方式;即使你在其他环境已装过,也需要单独安装一次。

- 对 OpenCode 说:

  ```
  Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
  ```

- 详细文档:[docs/README.opencode.md](https://github.com/obra/superpowers/blob/main/docs/README.opencode.md)

### Pi

以 Pi 包的形式从本仓库安装:

```bash
pi install git:github.com/obra/superpowers
```

本地开发时,可以把这份代码作为临时包加载运行:

```bash
pi -e /path/to/superpowers
```

Pi 包会加载 Superpowers 技能和一个小型扩展,该扩展在会话启动时和压缩(compaction)之后注入 `using-superpowers` 引导指令。Pi 原生支持技能,因此不需要兼容用的 `Skill` 工具。子代理和任务列表工具仍是可选的 Pi 伴侣包。

### Hermes Agent

以 Hermes 插件的形式从本仓库安装:

```bash
hermes plugins install obra/superpowers --enable
```

安装后请重启所有活跃的 Hermes 会话。注意:Hermes 没有压缩后钩子,如果非常长的会话在首轮就发生压缩,引导指令会丢失——此时若技能不再触发,请开一个新会话。

## 基本工作流

1. **brainstorming(头脑风暴)** — 在写代码之前激活。通过提问打磨粗略想法、探索替代方案、分节展示设计供你确认,并保存设计文档。

2. **using-git-worktrees(使用 Git Worktree)** — 在设计获批后激活。在新分支上创建隔离工作区,运行项目初始化,验证干净的测试基线。

3. **writing-plans(编写计划)** — 在设计获批后激活。把工作拆成小块任务(每个 2-5 分钟)。每个任务都有精确的文件路径、完整代码和验证步骤。

4. **subagent-driven-development(子代理驱动开发)或 executing-plans(执行计划)** — 在计划就绪后激活。为每个任务派出全新子代理并进行两阶段审查(先查规范符合性,再查代码质量),或者分批执行并在关键节点设人工检查点。

5. **test-driven-development(测试驱动开发)** — 在实现过程中激活。强制红-绿-重构循环:先写失败测试、看着它失败、写最小实现、看着测试通过、提交。测试之前写出来的代码一律删掉。

6. **requesting-code-review(请求代码评审)** — 在任务之间激活。对照计划进行评审,按严重程度报告问题。严重问题会阻断后续进度。

7. **finishing-a-development-branch(收尾开发分支)** — 在所有任务完成后激活。验证测试,提供选项(合并/提 PR/保留/丢弃),清理 worktree。

**代理在执行任何任务之前都会检查相关技能。** 这些是强制工作流,不是建议。

## 社区

Superpowers 由 [Jesse Vincent](https://blog.fsck.com) 和 [Prime Radiant](https://primeradiant.com) 的其他成员共同打造。

- **Discord**:[加入我们](https://discord.gg/35wsABTejz),获取社区支持、提问,分享你用 Superpowers 构建的东西
- **Issues**:https://github.com/obra/superpowers/issues
- **版本发布公告**:[订阅通知](https://primeradiant.com/superpowers/),第一时间了解新版本

## 包含哪些内容

### 技能库

**测试**
- **test-driven-development(测试驱动开发)** — 红-绿-重构循环(附测试反模式参考)

**调试**
- **systematic-debugging(系统化调试)** — 4 阶段根因分析流程(包含根因追踪、纵深防御、条件等待等技术)
- **verification-before-completion(完成前验证)** — 确保问题真的修好了

**协作**
- **brainstorming(头脑风暴)** — 苏格拉底式的设计打磨
- **writing-plans(编写计划)** — 详尽的实现计划
- **executing-plans(执行计划)** — 带检查点的分批执行
- **dispatching-parallel-agents(调度并行代理)** — 并发子代理工作流
- **requesting-code-review(请求代码评审)** — 评审前检查清单
- **receiving-code-review(接收代码评审)** — 如何回应评审反馈
- **using-git-worktrees(使用 Git Worktree)** — 并行开发分支
- **finishing-a-development-branch(收尾开发分支)** — 合并/PR 决策工作流
- **subagent-driven-development(子代理驱动开发)** — 带两阶段审查(规范符合性、代码质量)的快速迭代

**元技能**
- **writing-skills(编写技能)** — 按最佳实践创建新技能(附测试方法论)
- **using-superpowers(使用超能力)** — 技能系统入门

## 设计哲学

- **测试驱动开发** — 永远先写测试
- **系统化优于即兴发挥** — 流程胜过瞎猜
- **降低复杂度** — 简洁是首要目标
- **证据胜过声明** — 宣告成功之前先验证

阅读[原项目发布公告](https://blog.fsck.com/2025/10/09/superpowers/)。

## 参与贡献

Superpowers 的一般贡献流程如下。请注意:我们通常不接受新增技能的贡献,且对技能的任何更新都必须在所有受支持的编码代理上正常工作。

1. Fork 本仓库
2. 切换到 'dev' 分支
3. 为你的工作创建一个新分支
4. 遵循 `writing-skills` 技能来创建和测试新增或修改的技能
5. 提交 PR,务必填写拉取请求模板。

技能行为测试使用 [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals/) 提供的 drill 评估框架,克隆到 `evals/` 目录——配置方法见 `evals/README.md`。插件基础设施测试位于 `tests/` 目录,通过相应的 `run-*.sh` 或 `npm test` 运行。

完整指南见 `skills/writing-skills/SKILL.md`。

## 更新

Superpowers 的更新方式因编码代理而异,但通常是自动的。

## 许可证

MIT 许可证 - 详见 LICENSE 文件。

## 可视化伴侣遥测

由于技能和插件不会向创作者提供任何反馈,我们无从得知有多少人在使用 Superpowers。默认情况下,头脑风暴技能可选的可视化伴侣功能中,Prime Radiant 的徽标是从我们的网站加载的,其中包含你正在使用的 Superpowers 版本号。它不包含关于你的项目、提示词或编码代理的任何细节,我们也看不到你的点击或你在构建什么。这只是为了让我们大致了解有多少人、在用哪个版本使用 Superpowers。该功能 100% 可选,将环境变量 `SUPERPOWERS_DISABLE_TELEMETRY` 设为任意真值即可关闭。Superpowers 同时也遵循 Claude Code 的 `DISABLE_TELEMETRY` 和 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` 退出选项。

---

**代部署 / 定制服务 / 技术咨询 请添加微信:uaycar**

---

本项目为 obra/superpowers 的中文翻译版本,所有代码版权归原项目作者所有,遵循其原始 MIT 许可证。

**如果觉得有用,请给原项目点个 Star!** ⭐

- 原项目:https://github.com/obra/superpowers
