> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# OpenCode 支持设计

**日期:** 2025-11-22
**作者:** Bot & Jesse
**状态:** 设计完成,等待实现

## 概述

为 OpenCode.ai 添加完整的 superpowers 支持:采用 OpenCode 原生插件架构,并与现有 Codex 实现共享核心功能。

## 背景

OpenCode.ai 是一个类似 Claude Code 和 Codex 的编码 agent。此前将 superpowers 移植到 OpenCode 的尝试(PR #93、PR #116)都采用文件复制的方式。本设计另辟蹊径:使用 OpenCode 的 JavaScript/TypeScript 插件系统构建原生插件,同时与 Codex 实现共享代码。

### 各平台之间的关键差异

- **Claude Code**:Anthropic 原生插件系统 + 基于文件的 skills
- **Codex**:没有插件系统 → bootstrap markdown + CLI 脚本
- **OpenCode**:带事件 hook 和自定义工具 API 的 JavaScript/TypeScript 插件

### OpenCode 的 Agent 系统

- **主 agent**:Build(默认,完全权限)和 Plan(受限,只读)
- **子 agent**:General(研究、搜索、多步骤任务)
- **调用方式**:由主 agent 自动分派,或手动 `@mention` 语法
- **配置**:自定义 agent 放在 `opencode.json` 或 `~/.config/opencode/agent/`

## 架构

### 高层结构

1. **共享核心模块**(`lib/skills-core.js`)
   - 通用的技能发现与解析逻辑
   - 由 Codex 和 OpenCode 两个实现共用

2. **平台专属包装器**
   - Codex:CLI 脚本(`.codex/superpowers-codex`)
   - OpenCode:插件模块(`.opencode/plugin/superpowers.js`)

3. **技能目录**
   - 核心:`~/.config/opencode/superpowers/skills/`(或安装位置)
   - 个人:`~/.config/opencode/skills/`(覆盖核心技能)

### 代码复用策略

把 `.codex/superpowers-codex` 中的通用功能抽取到共享模块:

```javascript
// lib/skills-core.js
module.exports = {
  extractFrontmatter(filePath),      // Parse name + description from YAML
  findSkillsInDir(dir, maxDepth),    // Recursive SKILL.md discovery
  findAllSkills(dirs),                // Scan multiple directories
  resolveSkillPath(skillName, dirs), // Handle shadowing (personal > core)
  checkForUpdates(repoDir)           // Git fetch/status check
};
```

### 技能 Frontmatter 格式

当前格式(没有 `when_to_use` 字段):

```yaml
---
name: skill-name
description: Use when [condition] - [what it does]; [additional context]
---
```

## OpenCode 插件实现

### 自定义工具

**工具 1:`use_skill`**

把指定技能的内容加载进对话(等价于 Claude 的 Skill 工具)。

```javascript
{
  name: 'use_skill',
  description: 'Load and read a specific skill to guide your work',
  schema: z.object({
    skill_name: z.string().describe('Name of skill (e.g., "superpowers:brainstorming")')
  }),
  execute: async ({ skill_name }) => {
    const { skillPath, content, frontmatter } = resolveAndReadSkill(skill_name);
    const skillDir = path.dirname(skillPath);

    return `# ${frontmatter.name}
# ${frontmatter.description}
# Supporting tools and docs are in ${skillDir}
# ============================================

${content}`;
  }
}
```

**工具 2:`find_skills`**

列出所有可用技能及其元数据。

```javascript
{
  name: 'find_skills',
  description: 'List all available skills',
  schema: z.object({}),
  execute: async () => {
    const skills = discoverAllSkills();
    return skills.map(s =>
      `${s.namespace}:${s.name}
  ${s.description}
  Directory: ${s.directory}
`).join('\n');
  }
}
```

### 会话启动 Hook

新会话开始时(`session.started` 事件):

1. **注入 using-superpowers 内容**
   - using-superpowers 技能的完整内容
   - 确立强制工作流

2. **自动运行 find_skills**
   - 一开始就展示完整的可用技能列表
   - 附带每个技能所在的目录

3. **注入工具映射说明**
   ```markdown
   **Tool Mapping for OpenCode:**
   When skills reference tools you don't have, substitute:
   - `TodoWrite` → `update_plan`
   - `Task` with subagents → Use OpenCode subagent system (@mention)
   - `Skill` tool → `use_skill` custom tool
   - Read, Write, Edit, Bash → Your native equivalents

   **Skill directories contain:**
   - Supporting scripts (run with bash)
   - Additional documentation (read with read tool)
   - Utilities specific to that skill
   ```

4. **检查更新**(非阻塞)
   - 带超时的快速 git fetch
   - 有更新时发出通知

### 插件结构

```javascript
// .opencode/plugin/superpowers.js
const skillsCore = require('../../lib/skills-core');
const path = require('path');
const fs = require('fs');
const { z } = require('zod');

export const SuperpowersPlugin = async ({ client, directory, $ }) => {
  const superpowersDir = path.join(process.env.HOME, '.config/opencode/superpowers');
  const personalDir = path.join(process.env.HOME, '.config/opencode/skills');

  return {
    'session.started': async () => {
      const usingSuperpowers = await readSkill('using-superpowers');
      const skillsList = await findAllSkills();
      const toolMapping = getToolMappingInstructions();

      return {
        context: `${usingSuperpowers}\n\n${skillsList}\n\n${toolMapping}`
      };
    },

    tools: [
      {
        name: 'use_skill',
        description: 'Load and read a specific skill',
        schema: z.object({
          skill_name: z.string()
        }),
        execute: async ({ skill_name }) => {
          // Implementation using skillsCore
        }
      },
      {
        name: 'find_skills',
        description: 'List all available skills',
        schema: z.object({}),
        execute: async () => {
          // Implementation using skillsCore
        }
      }
    ]
  };
};
```

## 文件结构

```
superpowers/
├── lib/
│   └── skills-core.js           # 新增:共享技能逻辑
├── .codex/
│   ├── superpowers-codex        # 更新:改用 skills-core
│   ├── superpowers-bootstrap.md
│   └── INSTALL.md
├── .opencode/
│   ├── plugin/
│   │   └── superpowers.js       # 新增:OpenCode 插件
│   └── INSTALL.md               # 新增:安装指南
└── skills/                       # 保持不变
```

## 实现计划

### 阶段 1:重构共享核心

1. 创建 `lib/skills-core.js`
   - 从 `.codex/superpowers-codex` 抽取 frontmatter 解析
   - 抽取技能发现逻辑
   - 抽取路径解析(含覆盖处理)
   - 更新为只使用 `name` 和 `description`(不使用 `when_to_use`)

2. 更新 `.codex/superpowers-codex` 以使用共享核心
   - 从 `../lib/skills-core.js` 导入
   - 移除重复代码
   - 保留 CLI 包装逻辑

3. 测试 Codex 实现仍然正常
   - 验证 bootstrap 命令
   - 验证 use-skill 命令
   - 验证 find-skills 命令

### 阶段 2:构建 OpenCode 插件

1. 创建 `.opencode/plugin/superpowers.js`
   - 从 `../../lib/skills-core.js` 导入共享核心
   - 实现插件函数
   - 定义自定义工具(use_skill、find_skills)
   - 实现 session.started hook

2. 创建 `.opencode/INSTALL.md`
   - 安装说明
   - 目录设置
   - 配置指引

3. 测试 OpenCode 实现
   - 验证会话启动 bootstrap
   - 验证 use_skill 工具可用
   - 验证 find_skills 工具可用
   - 验证技能目录可访问

### 阶段 3:文档与收尾

1. 在 README 中加入 OpenCode 支持
2. 在主文档中加入 OpenCode 安装说明
3. 更新 RELEASE-NOTES
4. 测试 Codex 和 OpenCode 都能正常工作

## 后续步骤

1. **创建隔离工作区**(使用 git worktree)
   - 分支:`feature/opencode-support`

2. **在适用之处遵循 TDD**
   - 测试共享核心函数
   - 测试技能发现与解析
   - 两个平台的集成测试

3. **增量实现**
   - 阶段 1:重构共享核心 + 更新 Codex
   - 继续之前先验证 Codex 仍然正常
   - 阶段 2:构建 OpenCode 插件
   - 阶段 3:文档与收尾

4. **测试策略**
   - 在真实的 OpenCode 安装环境中手动测试
   - 验证技能加载、目录、脚本都能正常工作
   - 并排对比测试 Codex 和 OpenCode
   - 验证工具映射正确生效

5. **PR 与合并**
   - 创建包含完整实现的 PR
   - 在干净环境中测试
   - 合并到 main

## 收益

- **代码复用**:技能发现/解析拥有单一事实来源
- **可维护性**:bug 修复同时作用于两个平台
- **可扩展性**:便于未来添加更多平台(Cursor、Windsurf 等)
- **原生集成**:正确使用 OpenCode 的插件系统
- **一致性**:所有平台上保持一致的技能体验
