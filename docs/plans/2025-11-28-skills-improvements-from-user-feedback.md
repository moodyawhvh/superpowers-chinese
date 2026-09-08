> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 来自用户反馈的技能改进

**日期:** 2025-11-28
**状态:** 草稿
**来源:** 两个在真实开发场景中使用 superpowers 的 Claude 实例

---

## 执行摘要

两个 Claude 实例提供了来自实际开发会话的详细反馈。这些反馈暴露出当前技能中的**系统性缺口**——即便遵循了技能,仍让本可预防的 bug 溜了出去。

**关键洞见:** 这些是问题报告,而不只是解决方案提案。问题是真实的;解决方案需要仔细评估。

**关键主题:**
1. **验证缺口**——我们验证操作成功,却不验证它是否达成了预期结果
2. **流程卫生**——后台进程跨子代理累积并互相干扰
3. **上下文优化**——子代理收到太多无关信息
4. **缺少自我反思**——没有在交接前审视自身工作的提示
5. **Mock 安全**——mock 可能偏离接口而无人察觉
6. **技能激活**——技能存在,却没被阅读/使用

---

## 发现的问题

### 问题 1:配置变更验证缺口

**发生了什么:**
- 子代理测试"OpenAI 集成"
- 设置了 `OPENAI_API_KEY` 环境变量
- 收到状态 200 的响应
- 报告"OpenAI 集成正常"
- **但**响应里是 `"model": "claude-sonnet-4-20250514"`——实际用的还是 Anthropic

**根因:**
`verification-before-completion` 检查操作是否成功,却不检查结果是否反映了预期的配置变更。

**影响:** 高——集成测试给出虚假信心,bug 带上生产。

**典型失败模式:**
- 切换 LLM 提供商 → 验证了状态 200,却不检查模型名
- 开启功能开关 → 验证了无报错,却不检查功能是否真正生效
- 更换环境 → 验证了部署成功,却不检查环境变量

---

### 问题 2:后台进程累积

**发生了什么:**
- 会话期间派发了多个子代理
- 各自启动了后台服务进程
- 进程不断累积(4 个以上服务器在跑)
- 失效进程仍占用着端口
- 后续 E2E 测试打到了配置错误的失效服务器
- 测试结果混乱/错误

**根因:**
子代理是无状态的——不知道先前子代理启动过什么进程。没有清理协议。

**影响:** 中高——测试打到错误服务器、假通过/假失败、调试混乱。

---

### 问题 3:子代理提示词的上下文膨胀

**发生了什么:**
- 标准做法:让子代理读完整计划文件
- 实验:只给任务 + 模式 + 文件 + 验证命令
- 结果:更快、更专注,一次通过更常见

**根因:**
子代理把 token 和注意力浪费在无关的计划章节上。

**影响:** 中——执行更慢,失败尝试更多。

**有效的做法:**
```
You are adding a single E2E test to packnplay's test suite.

**Your task:** Add `TestE2E_FeaturePrivilegedMode` to `pkg/runner/e2e_test.go`

**What to test:** A local devcontainer feature that requests `"privileged": true`
in its metadata should result in the container running with `--privileged` flag.

**Follow the exact pattern of TestE2E_FeatureOptionValidation** (at the end of the file)

**After writing, run:** `go test -v ./pkg/runner -run TestE2E_FeaturePrivilegedMode -timeout 5m`
```

---

### 问题 4:交接前缺少自我反思

**发生了什么:**
- 加入了自我反思提示:"用新鲜的眼光审视你的工作——哪里可以更好?"
- 任务 5 的 implementer 判定测试失败源于实现 bug,而非测试 bug
- 定位到第 99 行:`strings.Join(metadata.Entrypoint, " ")` 产生了非法的 Docker 语法
- 若没有自我反思,只会报告"测试失败"而不给出根因

**根因:**
implementer 不会自发地在报告完成前退一步审视自己的工作。

**影响:** 中——本可由 implementer 自己抓住的 bug 被丢给了 reviewer。

---

### 问题 5:Mock 与接口漂移

**发生了什么:**
```typescript
// Interface defines close()
interface PlatformAdapter {
  close(): Promise<void>;
}

// Code (BUGGY) calls cleanup()
await adapter.cleanup();

// Mock (MATCHES BUG) defines cleanup()
vi.mock('web-adapter', () => ({
  WebAdapter: vi.fn().mockImplementation(() => ({
    cleanup: vi.fn().mockResolvedValue(undefined),  // Wrong!
  })),
}));
```
- 测试通过
- 运行时崩溃:"adapter.cleanup is not a function"

**根因:**
mock 是照着有 bug 的代码在调用什么推导的,而不是照接口定义。TypeScript 抓不住方法名写错的行内 mock。

**影响:** 高——测试给出虚假信心,运行时崩溃。

**为什么 testing-anti-patterns 没能预防:**
该技能覆盖了测试 mock 行为、以及不理解就乱 mock 的问题,但没有覆盖"从接口而非实现推导 mock"这一具体模式。

---

### 问题 6:代码评审员的文件访问

**发生了什么:**
- 派出了代码评审子代理
- 找不到测试文件:"该文件似乎不存在于仓库中"
- 文件其实存在
- reviewer 不知道要先显式读取它

**根因:**
reviewer 提示词中没有包含明确的文件读取指令。

**影响:** 低到中——评审失败或不完整。

---

### 问题 7:修复流程延迟

**发生了什么:**
- implementer 在自我反思时发现了 bug
- implementer 知道怎么修
- 当前流程:报告 → 我派 fixer → fixer 修复 → 我验证
- 多出的往返只增加延迟,不增加价值

**根因:**
implementer 已完成诊断时,implementer 与 fixer 的角色仍被僵硬割裂。

**影响:** 低——只有延迟,无正确性问题。

---

### 问题 8:技能没被阅读

**发生了什么:**
- `testing-anti-patterns` 技能存在
- 无论人还是子代理,写测试前都没读它
- 本可预防部分问题(但非全部——见问题 5)

**根因:**
没有任何机制强制子代理阅读相关技能;没有提示词包含"读技能"这一步。

**影响:** 中——技能投入若不被使用就等于白费。

---

## 改进提案

### 1. verification-before-completion:新增配置变更验证

**新增一节:**

```markdown
## Verifying Configuration Changes

When testing changes to configuration, providers, feature flags, or environment:

**Don't just verify the operation succeeded. Verify the output reflects the intended change.**

### Common Failure Pattern

Operation succeeds because *some* valid config exists, but it's not the config you intended to test.

### Examples

| Change | Insufficient | Required |
|--------|-------------|----------|
| Switch LLM provider | Status 200 | Response contains expected model name |
| Enable feature flag | No errors | Feature behavior actually active |
| Change environment | Deploy succeeds | Logs/vars reference new environment |
| Set credentials | Auth succeeds | Authenticated user/context is correct |

### Gate Function

```
BEFORE claiming configuration change works:

1. IDENTIFY: What should be DIFFERENT after this change?
2. LOCATE: Where is that difference observable?
   - Response field (model name, user ID)
   - Log line (environment, provider)
   - Behavior (feature active/inactive)
3. RUN: Command that shows the observable difference
4. VERIFY: Output contains expected difference
5. ONLY THEN: Claim configuration change works

Red flags:
  - "Request succeeded" without checking content
  - Checking status code but not response body
  - Verifying no errors but not positive confirmation
```
```

**为什么有效:**
强制验证"意图",而不只是操作成功。

---

### 2. subagent-driven-development:为 E2E 测试新增流程卫生

**新增一节:**

```markdown
## Process Hygiene for E2E Tests

When dispatching subagents that start services (servers, databases, message queues):

### Problem

Subagents are stateless - they don't know about processes started by previous subagents. Background processes persist and can interfere with later tests.

### Solution

**Before dispatching E2E test subagent, include cleanup in prompt:**

```
BEFORE starting any services:
1. Kill existing processes: pkill -f "<service-pattern>" 2>/dev/null || true
2. Wait for cleanup: sleep 1
3. Verify port free: lsof -i :<port> && echo "ERROR: Port still in use" || echo "Port free"

AFTER tests complete:
1. Kill the process you started
2. Verify cleanup: pgrep -f "<service-pattern>" || echo "Cleanup successful"
```

### Example

```
Task: Run E2E test of API server

Prompt includes:
"Before starting the server:
- Kill any existing servers: pkill -f 'node.*server.js' 2>/dev/null || true
- Verify port 3001 is free: lsof -i :3001 && exit 1 || echo 'Port available'

After tests:
- Kill the server you started
- Verify: pgrep -f 'node.*server.js' || echo 'Cleanup verified'"
```

### Why This Matters

- Stale processes serve requests with wrong config
- Port conflicts cause silent failures
- Process accumulation slows system
- Confusing test results (hitting wrong server)
```

**权衡分析:**
- 给提示词增加了样板内容
- 但能避免极其烧脑的调试
- 对 E2E 测试子代理来说值得

---

### 3. subagent-driven-development:新增精简上下文选项

**修改 Step 2:用子代理执行任务**

**改前:**
```
Read that task carefully from [plan-file].
```

**改后:**
```
## Context Approaches

**Full Plan (default):**
Use when tasks are complex or have dependencies:
```
Read Task N from [plan-file] carefully.
```

**Lean Context (for independent tasks):**
Use when task is standalone and pattern-based:
```
You are implementing: [1-2 sentence task description]

File to modify: [exact path]
Pattern to follow: [reference to existing function/test]
What to implement: [specific requirement]
Verification: [exact command to run]

[Do NOT include full plan file]
```

**Use lean context when:**
- Task follows existing pattern (add similar test, implement similar feature)
- Task is self-contained (doesn't need context from other tasks)
- Pattern reference is sufficient (e.g., "follow TestE2E_FeatureOptionValidation")

**Use full plan when:**
- Task has dependencies on other tasks
- Requires understanding of overall architecture
- Complex logic that needs context
```

**示例:**
```
Lean context prompt:

"You are adding a test for privileged mode in devcontainer features.

File: pkg/runner/e2e_test.go
Pattern: Follow TestE2E_FeatureOptionValidation (at end of file)
Test: Feature with `"privileged": true` in metadata results in `--privileged` flag
Verify: go test -v ./pkg/runner -run TestE2E_FeaturePrivilegedMode -timeout 5m

Report: Implementation, test results, any issues."
```

**为什么有效:**
降低 token 消耗、提升专注度,在合适场景下完成更快。

---

### 4. subagent-driven-development:新增自我反思步骤

**修改 Step 2:用子代理执行任务**

**在提示词模板中加入:**

```
When done, BEFORE reporting back:

Take a step back and review your work with fresh eyes.

Ask yourself:
- Does this actually solve the task as specified?
- Are there edge cases I didn't consider?
- Did I follow the pattern correctly?
- If tests are failing, what's the ROOT CAUSE (implementation bug vs test bug)?
- What could be better about this implementation?

If you identify issues during this reflection, fix them now.

Then report:
- What you implemented
- Self-reflection findings (if any)
- Test results
- Files changed
```

**为什么有效:**
在交接前抓住 implementer 自己能发现的 bug。有记录的案例:通过自我反思发现了 entrypoint bug。

**权衡:**
每个任务多花约 30 秒,但能在评审前拦住问题。

---

### 5. requesting-code-review:新增显式文件读取

**修改 code-reviewer 模板:**

**在开头加入:**

```markdown
## Files to Review

BEFORE analyzing, read these files:

1. [List specific files that changed in the diff]
2. [Files referenced by changes but not modified]

Use Read tool to load each file.

If you cannot find a file:
- Check exact path from diff
- Try alternate locations
- Report: "Cannot locate [path] - please verify file exists"

DO NOT proceed with review until you've read the actual code.
```

**为什么有效:**
显式指令避免"找不到文件"问题。

---

### 6. testing-anti-patterns:新增 Mock-接口漂移反模式

**新增反模式 6:**

```markdown
## Anti-Pattern 6: Mocks Derived from Implementation

**The violation:**
```typescript
// Code (BUGGY) calls cleanup()
await adapter.cleanup();

// Mock (MATCHES BUG) has cleanup()
const mock = {
  cleanup: vi.fn().mockResolvedValue(undefined)
};

// Interface (CORRECT) defines close()
interface PlatformAdapter {
  close(): Promise<void>;
}
```

**Why this is wrong:**
- Mock encodes the bug into the test
- TypeScript can't catch inline mocks with wrong method names
- Test passes because both code and mock are wrong
- Runtime crashes when real object is used

**The fix:**
```typescript
// ✅ GOOD: Derive mock from interface

// Step 1: Open interface definition (PlatformAdapter)
// Step 2: List methods defined there (close, initialize, etc.)
// Step 3: Mock EXACTLY those methods

const mock = {
  initialize: vi.fn().mockResolvedValue(undefined),
  close: vi.fn().mockResolvedValue(undefined),  // From interface!
};

// Now test FAILS because code calls cleanup() which doesn't exist
// That failure reveals the bug BEFORE runtime
```

### Gate Function

```
BEFORE writing any mock:

  1. STOP - Do NOT look at the code under test yet
  2. FIND: The interface/type definition for the dependency
  3. READ: The interface file
  4. LIST: Methods defined in the interface
  5. MOCK: ONLY those methods with EXACTLY those names
  6. DO NOT: Look at what your code calls

  IF your test fails because code calls something not in mock:
    ✅ GOOD - The test found a bug in your code
    Fix the code to call the correct interface method
    NOT the mock

  Red flags:
    - "I'll mock what the code calls"
    - Copying method names from implementation
    - Mock written without reading interface
    - "The test is failing so I'll add this method to the mock"
```

**Detection:**

When you see runtime error "X is not a function" and tests pass:
1. Check if X is mocked
2. Compare mock methods to interface methods
3. Look for method name mismatches
```

**为什么有效:**
直接对应反馈中的失败模式。

---

### 7. subagent-driven-development:要求测试子代理阅读技能

**任务涉及测试时,在提示词模板中加入:**

```markdown
BEFORE writing any tests:

1. Read testing-anti-patterns skill:
   Use Skill tool: superpowers:testing-anti-patterns

2. Apply gate functions from that skill when:
   - Writing mocks
   - Adding methods to production classes
   - Mocking dependencies

This is NOT optional. Tests that violate anti-patterns will be rejected in review.
```

**为什么有效:**
确保技能被真正使用,而不只是存在。

**权衡:**
每个任务多花一些时间,但能防住整类 bug。

---

### 8. subagent-driven-development:允许 implementer 修复自发现的问题

**修改 Step 2:**

**现状:**
```
Subagent reports back with summary of work.
```

**提案:**
```
Subagent performs self-reflection, then:

IF self-reflection identifies fixable issues:
  1. Fix the issues
  2. Re-run verification
  3. Report: "Initial implementation + self-reflection fix"

ELSE:
  Report: "Implementation complete"

Include in report:
- Self-reflection findings
- Whether fixes were applied
- Final verification results
```

**为什么有效:**
implementer 已经知道修法时减少延迟。有记录的案例:entrypoint bug 本可省去一次往返。

**权衡:**
提示词稍复杂,但端到端更快。

---

## 实施计划

### Phase 1:高影响、低风险(先做)

1. **verification-before-completion:配置变更验证**
   - 新增清晰,不改既有内容
   - 解决高影响问题(测试虚假信心)
   - 文件:`skills/verification-before-completion/SKILL.md`

2. **testing-anti-patterns:Mock-接口漂移**
   - 新增反模式,不修改既有内容
   - 解决高影响问题(运行时崩溃)
   - 文件:`skills/testing-anti-patterns/SKILL.md`

3. **requesting-code-review:显式文件读取**
   - 模板简单增补
   - 修复具体问题(reviewer 找不到文件)
   - 文件:`skills/requesting-code-review/SKILL.md`

### Phase 2:中等改动(谨慎测试)

4. **subagent-driven-development:流程卫生**
   - 新增小节,不改工作流
   - 解决中高影响问题(测试可靠性)
   - 文件:`skills/subagent-driven-development/SKILL.md`

5. **subagent-driven-development:自我反思**
   - 修改提示词模板(风险较高)
   - 但有抓住 bug 的记录佐证
   - 文件:`skills/subagent-driven-development/SKILL.md`

6. **subagent-driven-development:技能阅读要求**
   - 增加提示词开销
   - 但确保技能被真正使用
   - 文件:`skills/subagent-driven-development/SKILL.md`

### Phase 3:优化(先验证)

7. **subagent-driven-development:精简上下文选项**
   - 增加复杂度(两种方式并存)
   - 需要验证不会引起混淆
   - 文件:`skills/subagent-driven-development/SKILL.md`

8. **subagent-driven-development:允许 implementer 自行修复**
   - 改变工作流(风险较高)
   - 属于优化,而非 bug 修复
   - 文件:`skills/subagent-driven-development/SKILL.md`

---

## 建议

**立即推进 Phase 1:**
- verification-before-completion:配置变更验证
- testing-anti-patterns:Mock-接口漂移
- requesting-code-review:显式文件读取

**定稿前与 Jesse 一起测试 Phase 2:**
- 就自我反思的影响收集反馈
- 验证流程卫生方案
- 确认技能阅读要求值得这点开销

**Phase 3 暂缓,等待验证:**
- 精简上下文需要实测
- implementer 自行修复的工作流变更需要仔细评估

这些改动解决用户记录的真实问题,同时把"把技能改糟"的风险降到最低。

> 注:因篇幅所限,本文档翻译了核心章节,完整内容见原项目。
