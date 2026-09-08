> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 文档评审系统设计

## 概述

在 superpowers 工作流中新增两个评审阶段:

1. **规格文档评审** - 在 brainstorming 之后、writing-plans 之前
2. **计划文档评审** - 在 writing-plans 之后、实现之前

两者都遵循实现评审所用的迭代循环模式。

## 规格文档评审器

**目的:** 验证规格完整、一致,并可用于实现规划。

**位置:** `skills/brainstorming/spec-document-reviewer-prompt.md`

**检查内容:**

| 类别 | 检查要点 |
|----------|------------------|
| 完整性 | TODO、占位符、"TBD"、未写完的章节 |
| 覆盖面 | 缺失的错误处理、边界情况、集成点 |
| 一致性 | 内部矛盾、相互冲突的需求 |
| 清晰度 | 模糊的需求 |
| YAGNI | 未被要求的功能、过度设计 |

**输出格式:**
```
## Spec Review

**Status:** Approved | Issues Found

**Issues (if any):**
- [Section X]: [issue] - [why it matters]

**Recommendations (advisory):**
- [suggestions that don't block approval]
```

**评审循环:** 发现问题 -> brainstorming agent 修复 -> 重新评审 -> 重复直到通过。

**派发机制:** 使用 Task 工具并指定 `subagent_type: general-purpose`。评审器提示模板提供完整 prompt。brainstorming 技能的控制器负责派发评审器。

## 计划文档评审器

**目的:** 验证计划完整、与规格一致,并有合理的任务拆分。

**位置:** `skills/writing-plans/plan-document-reviewer-prompt.md`

**检查内容:**

| 类别 | 检查要点 |
|----------|------------------|
| 完整性 | TODO、占位符、未完成的任务 |
| 规格对齐 | 计划覆盖规格需求,无范围蔓延 |
| 任务拆分 | 任务原子化、边界清晰 |
| 任务语法 | 任务与步骤使用 checkbox 语法 |
| 块大小 | 每块不超过 1000 行 |

**块(chunk)定义:** 块是计划文档内任务的逻辑分组,以 `## Chunk N: <name>` 标题分隔。writing-plans 技能按逻辑阶段(如 "Foundation"、"Core Features"、"Integration")划定这些边界。每个块应足够自包含,可独立评审。

**规格对齐验证:** 评审器同时收到:
1. 计划文档(或当前块)
2. 规格文档的路径以供参考

评审器读取两者并比对需求覆盖情况。

**输出格式:** 与规格评审器相同,但范围限于当前块。

**评审流程(逐块):**
1. writing-plans 创建块 N
2. 控制器带着块 N 的内容和规格路径派发 plan-document-reviewer
3. 评审器读取块和规格,返回结论
4. 若有问题:writing-plans agent 修复块 N,回到步骤 2
5. 若通过:进入块 N+1
6. 重复直到所有块通过

**派发机制:** 与规格评审器相同 —— Task 工具加 `subagent_type: general-purpose`。

## 更新后的工作流

```
brainstorming -> spec -> SPEC REVIEW LOOP -> writing-plans -> plan -> PLAN REVIEW LOOP -> implementation
```

**规格评审循环:**
1. 规格完成
2. 派发评审器
3. 若有问题:修复 -> 回到 2
4. 若通过:继续

**计划评审循环:**
1. 块 N 完成
2. 为块 N 派发评审器
3. 若有问题:修复 -> 回到 2
4. 若通过:下一块或进入实现

## Markdown 任务语法

任务与步骤使用 checkbox 语法:

```markdown
- [ ] ### Task 1: Name

- [ ] **Step 1:** Description
  - File: path
  - Command: cmd
```

## 错误处理

**评审循环终止:**
- 不设硬性迭代上限 —— 循环持续到评审器通过为止
- 若循环超过 5 轮迭代,控制器应将此情况上报人类寻求指示
- 人类可选择:继续迭代、带着已知问题通过,或中止

**分歧处理:**
- 评审器是顾问性质 —— 只标记问题,不做阻塞
- 如果 agent 认为评审器的反馈有误,应在修复中说明理由
- 同一问题在 3 轮迭代后分歧仍在,上报人类

**格式错误的评审输出:**
- 控制器应校验评审器输出包含必需字段(Status,以及适用时的 Issues)
- 若格式错误,附带期望格式的说明重新派发评审器
- 出现 2 次格式错误响应后,上报人类

## 需要改动的文件

**新文件:**
- `skills/brainstorming/spec-document-reviewer-prompt.md`
- `skills/writing-plans/plan-document-reviewer-prompt.md`

**修改的文件:**
- `skills/brainstorming/SKILL.md` - 在规格写完后加入评审循环
- `skills/writing-plans/SKILL.md` - 加入逐块评审循环,更新任务语法示例
