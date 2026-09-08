<div align="center">

# superpowers 中文翻译版

**[中文版] superpowers — 一套真正好用的 AI 编程代理技能框架与软件开发方法论**

[![原项目](https://img.shields.io/badge/原项目-obra--superpowers-blue?style=flat-square&logo=github)](https://github.com/obra/superpowers)
[![中文文档](https://img.shields.io/badge/中文文档-README.zh--CN.md-orange?style=flat-square)](README.zh-CN.md)
[![GitHub Stars](https://img.shields.io/github/stars/obra/superpowers?style=flat-square&label=原项目Stars)](https://github.com/obra/superpowers/stargazers)
[![微信联系](https://img.shields.io/badge/微信-uaycar-brightgreen?style=flat-square&logo=wechat)](#)

</div>

---

> 这是 [obra/superpowers](https://github.com/obra/superpowers) 的中文翻译版本。
> 完整源代码请访问原项目:https://github.com/obra/superpowers

**代部署 / 定制服务 / 技术咨询 请添加微信:uaycar**

---

## 📖 项目简介

Superpowers 是一套为 AI 编程代理打造的完整软件开发方法论,由一组可组合的技能(skills)和会话启动指令构成,支持 Claude Code、Codex、Cursor、Gemini CLI、GitHub Copilot CLI 等十余种主流编码代理。它解决的核心问题是:AI 代理拿到需求就闷头写代码、缺乏设计、不写测试、容易跑偏——Superpowers 让代理先通过头脑风暴和你对齐设计,再把工作拆成带完整代码和验证步骤的小任务,最后用子代理驱动开发和强制 TDD 把计划真正落地。设计签核之后,代理可以按计划自主连续工作数小时不偏离方向。技能全部按场景自动触发,你不需要任何额外操作,代理"自带超能力"。

## ✨ 主要特性

- 🧠 **头脑风暴先行** — 写代码前先通过提问打磨需求、探索替代方案,设计文档分节呈现供你确认
- 📋 **计划精细拆解** — 把工作拆成 2-5 分钟的小任务,每个任务带精确文件路径、完整代码与验证步骤
- 🤖 **子代理驱动开发** — 每个任务派出全新子代理执行,经过规范符合性 + 代码质量两阶段审查再推进
- ✅ **强制 TDD** — 严格执行红-绿-重构循环:先写失败测试、再写最小实现,测试先行的代码才会被保留
- 🌿 **Git Worktree 隔离** — 设计批准后自动在新分支上创建独立工作区,并验证干净的测试基线
- 🔍 **系统化调试** — 4 阶段根因分析流程,声明完成之前必须实际验证修复效果
- 🧩 **多代理支持** — 一套技能覆盖 Claude Code、Codex、Cursor、Gemini CLI、Copilot CLI 等 14 种环境
- ⚡ **自动触发** — 技能在对应场景自动激活,是强制工作流而非建议,无需手动唤起
- 🛠️ **技能可扩展** — 内置 writing-skills 技能,带你按最佳实践创建并测试自己的新技能

## 📁 文件说明

| 文件 | 说明 |
|:-----|:-----|
| README.md | 本文件(中文简介) |
| README.zh-CN.md | 详细中文文档(完整汉化) |

## 🚀 快速开始

以 Claude Code 为例,从官方插件市场一键安装:

```bash
/plugin install superpowers@claude-plugins-official
```

或通过 Superpowers 自有市场安装:

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

其他主流代理的安装方式(完整列表见中文文档):

```bash
# Codex CLI:输入 /plugins,搜索 superpowers,选择 Install Plugin
# Cursor:
/add-plugin superpowers
# Gemini CLI:
gemini extensions install https://github.com/obra/superpowers
# Devin CLI:
devin plugins install obra/superpowers
```

基本工作流:头脑风暴 → 创建 Git Worktree → 拆解计划 → 子代理逐任务执行(两阶段审查)→ TDD 实现 → 任务间代码审查 → 合并/提 PR 收尾。

完整源代码与最新版本请访问原项目:https://github.com/obra/superpowers

## 📞 联系方式

**代部署 / 定制服务 / 技术咨询 请添加微信:uaycar**

---

本项目为 [obra/superpowers](https://github.com/obra/superpowers) 的中文翻译版本,所有代码版权归原项目作者所有,遵循其原始许可证。

**如果觉得有用,请给原项目点个 Star!** ⭐
