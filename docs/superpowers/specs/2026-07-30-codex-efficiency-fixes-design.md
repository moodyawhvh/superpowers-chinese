> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# Codex 效率修复 —— 设计

日期:2026-07-30
状态:已获 Jesse 批准(会话内)
分支:基于 `dev` 的 `codex-efficiency-fixes`

## 依据来源

- 评测活动收官报告:`superpowers-autoresearch/reports/2026-07-codex-efficiency-campaign.md`
  (处置方案表 §4;下文每项处置方案都有对应评分器和实测的
  `dev` 基线)。
- Codex 源码侦察:`superpowers-autoresearch/docs/2026-07-29-codex-multiagent-v2-capabilities.md`
  (对 Codex CLI 源码给出 file:line 级引用;为 T2、T3、T5 提供依据)。
- 已发布的实验报告:`superpowers-evals/docs/experiments/`。
- Drew 的 spinout 补丁栈(PR #2036、#2035)仅是**证据,而非采纳文本**:
  Jesse 希望在采纳其中任何内容之前先深入研究这些修复;它们只为问题陈述提供输入。

## 目标

将 codex-efficiency 评测活动中证据充分的五项处置方案作为 superpowers 技能/文档改动交付;每项在切出 PR 之前,都要由活动的评分器对照预先注册的判据评分。随后进入 Phase 2(收官处置表中的其余全部条目),每项都必须先完成新的基线工作才可放行。

## 范围决策(已与 Jesse 敲定)

- **Phase 1 = 证据充分的五项**(下文 T1–T5)。Phase 2 的每一项都必须先测得失败基线才能交付修复(判别规则:零样本无结论即止步)。
- **单一分支,每个处置方案一个 PR。** 开发与测试都在 `codex-efficiency-fixes` 上进行;某项处置方案达标后,即连同其评测证据切出一个针对 `dev` 的独立 PR。未经 Jesse 逐 PR 批准不得合并。
- **T4 以全局回归测试组跨 harness 交付**(Claude Code、Codex、Gemini),采用 variant C 形态:仪式随场景伸缩,审批永不缩水。

## 五项处置方案

### T1. SDD 禁止 worker 自派评审

**证据:** 4 个语料库中 9/9 个 depth-2 派生都是 implementer 派出的 reviewer;这 9 个全部与本就由 controller 派发的评审构成同任务重复。派发契约从未说明评审不是 worker 的职责;implementer 提示词中的 "self-review" 在子代理可再派生的 harness(Codex)上被实体化成了 reviewer 子代理。

**改动:**
- `skills/subagent-driven-development/implementer-prompt.md`:加入明确的"你不派生子代理"条款——self-review 就是指阅读自己的 diff;所有评审派发都归 controller;你自己派出的 reviewer 只会重复流程本就提供的评审。
- `skills/subagent-driven-development/SKILL.md`:在任务循环中加入一条派发契约说明,并在 Red Flags 中新增一行:"独立评审会让我的报告更扎实" → 评审是 controller 的下一步;你的 reviewer 是多余的席位。
- 措辞与 harness 无关(在子代理无法派生的 harness 上为无操作)。

**评分方式:** `score_e6.py`(按派生者角色统计 depth-2 派生与重复评审族群);同范围变体用 `score_e5.py`。
**基线:** 9/9 由 worker 派出,0 个反例。
**判据:** worker 派出的 depth-2 派生为 0,且评审覆盖保持不变(每个任务仍恰好获得一次 controller 派发的任务评审)。

### T2. 事件驱动的等待

**证据:** 每个语料库中都有 60–78% 的 `wait_agent` 调用超时(dev 67.1%,spinout 60.2%)。源码侦察:V2 的等待是事件订阅而非轮询——一次长等待的唤醒延迟与 10 秒轮询相同,调用次数却只有约 1/90;已完成子代理的 FINAL_ANSWER 会被推入父代理邮箱,并随下一次模型请求排空,完全无需等待。

**改动**(`skills/using-superpowers/references/codex-tools.md`):
- 永远不要短超时轮询。
- 只要本地还有工作,就不要等待——子代理结果会经邮箱随你的下一轮到达。
- 真正空闲时,只发出一次 `wait_agent`,并使用长 `timeout_ms`(900000+;harness 上限 3600000)。
- 写明 V2 注意事项:完成邮件携带 `trigger_turn=false`,不会唤醒空闲的 controller——而这正是 `wait_agent` 唯一的职责。

**评分方式:** `score_e7.py`(超时率、轮询间隔节奏、缓存重计费估算——重计费数字保持"估算"标注)。
**基线:** dev 超时率 67.1%。
**判据:** 超时率 < 25%,且任务完成度不受损。

### T3. codex-tools.md 勘误

**证据:** 现行指南中有五条说法与 Codex 源码相矛盾(能力文档中均附有 file:line 引用):
1. `close_agent` 在多代理 V2 中并不存在(仅 V1 有)。V2 会自动 LRU 驱逐已完成的子代理;不关闭毫无代价;`followup_task` 会透明地重新加载被驱逐的子代理。
2. 修复轮始终可以通过 `followup_task` 恢复 implementer——dev 版"如果你的 harness 无法向已派生代理再发一条消息,就把每轮修复当作全新 implementer 派发"的分支在 V2 上是死路。
3. 角色文件(`~/.codex/agents/**.toml`)在隔离 fork 上确实会通过 `agent_type` 附加到派生(0.145+)。
4. 全历史 fork 接受 `model`/`reasoning_effort` 覆盖;只有 `agent_type` 被拒。(出于上下文卫生的原因,隔离 fork 仍是 SDD 指南,此次如实表述。)
5. 派发指南绝不能点名非 V2 模型预设——V2 派生白名单只接受 v2 预设,其他一律硬报错。

**改动:** 重写 `skills/using-superpowers/references/codex-tools.md` 的多代理段落,做到版本诚实(V1 与 V2 行为有差异之处明确标注)。

**评分方式:** 源码引用(已核实);共享测试组上评分器无回归。`score_e8.py` 保留为 V1/V2 架构探测器,而非卫生评分器——不会交付任何 `close_agent` 检查清单。

### T4. Brainstorming 三路径路由(variant C:审批永在)

**证据:** micro——现行 HARD-GATE 文本把有界任务 5/5 全推到 FULL 仪式,而 Z-null(无指导)与三路径路由都能做到 5/5 区分:绝对化措辞压制了模型天然具备的判别力。FULL 测试组——仪式体量中等放大(bounded 对 arch 分别为 16.7 与 24.0 次工具调用),但双文档仪式(spec 文件 → plan 文件)在每次重复中都无条件执行。实测的浪费在于无条件的产物仪式,而非审批门。

**设计(variant C):** 三条路径调节的是产物规格;每条路径都在实现前保留人工审批:
- **Spike**(可行性问题,明确为一次性):用 2–3 句话陈述问题与拟探测内容,得到点头即开工。不写文档。结论以建议形式返回;任何产出都保持"一次性"标注。
- **Bounded**(对既有且已被理解的流程做范围明确的改动):在对话中陈述简短设计,获批后实现。不写 spec 文件,不调用 writing-plans。
- **Architectural**(重组组件、新增子系统、公开接口变更):走现有完整流程——spec 文档、评审、writing-plans。

**护栏(全部随路由器一起交付):**
- 分类结论要说出口("这个看起来是有界的,所以我直接在这里给出简短设计,而不写 spec"),让人可以否决。
- 在两条路径之间拿不准时,选更重的那条。
- 单向棘轮:路径中途发现隐藏复杂度只能升级路径;任务中途绝不降级。
- 新增 Red Flags 行,针对"把分类当逃生门"("我把它叫做有界,就能跳过文档")。

**改动**(`skills/brainstorming/SKILL.md`):HARD-GATE 保留"审批前不得实现",去掉"无论看起来多简单"这一仪式驱动语;反模式小节重新定调(罪在跳过审批,而非跳过文档);检查清单第 6–9 步归入 architectural 路径;流程图加入路由器;新增 Red Flags 行。这是需要精细调校的内容——编辑遵循 writing-skills 方法论,且仅连同下述完整评测证据一起交付。

**评分方式(三层):**
1. **Micro**(`ceremony-path-micro.py`,改版):variant C 原文,外加活动从未测过的对抗性模糊简报(一个模式匹配上像 bounded、实则暗藏公开接口变更的任务)。判据:spike/bounded/arch 能区分(每格 ≥4/5);模糊简报升级到 FULL(≥4/5);arch 永不降级(5/5)。
2. **Codex ceremony 测试组:** `cx-ceremony-{spike,bounded,arch}` 跑在 fix 臂上,各 3 次重复,`score_e4.py` 普查。判据:bounded 重复出现审批回合,但零个落盘 spec 文件、零次 writing-plans 仪式;arch 重复保持完整双文档流程;spike 重复保持最小。
3. **全局回归测试组:** 同样三个 ceremony 场景在 Claude Code 和 Gemini 上(测试台工作:这些场景目前仅对 codex 开放),各 3 次重复;外加触发验收检查("Let's make a react todo list" 自动触发 brainstorming 并进入完整/architectural 路径)在三个 harness 上全部执行。

### T5. 子代理派生时显式指定模型

**证据:** CLI 0.146 下根派生 100% 显式指定模型(dev 14/14);现存的缺口在 depth-2——2/2 个子代理派生都省略了 `model`。源码侦察:`model` 不带 `reasoning_effort` 时,effort 会被重置为该模型(MODEL)的默认值,而非父代理的。

**改动**(`skills/using-superpowers/references/codex-tools.md`):
- 你发出的每一次派生——包括以子代理身份发出的——都同时设置 `model` 与 `reasoning_effort`;并点名 effort 重置陷阱。
- 建议在 `~/.codex/config.toml` 中配置 `[agents].default_subagent_model` 与 `[agents].default_subagent_reasoning_effort`,作为机器级兜底,拦截一切漏网之鱼。

**评分方式:** `score_e1.py`(按深度统计每次派生的显式模型率)在共享测试组上。
**基线:** depth-2:0/2 显式。
**判据:** 任何深度的每一次派生都携带显式 model + effort。预先注册的注意事项:若 T1 完全消灭了 depth-2 派生,T5 按"根派生回归(保持 100%)+ 文档正确性"评分,depth-2 记为零样本无结论——此时配置兜底即为实际生效机制。

## 评分计划

- **共享 SDD 测试组**承载 T1、T2、T5:`cx-sdd-small`,fix 分支臂(`/tmp/sp-arm-fix`),两条容器泳道共 8 次重复。dev 基线已测得,无需重跑。
- **T4 测试组**如上所列(micro + codex ceremony + 全局回归)。
- **预注册:** 每个测试组运行前,先在 `superpowers-autoresearch/logs/2026-07-30-codex-efficiency-fixes.md` 写入假设日志条目(预测、评分器、判据)。既定规则继续沿用:日志只追加、fix 臂运行中的评分器命中需人工核查(非循环验证)、不提交原始 rollout、每个结论中正确性与成本并重。
- **归因:** 各评分器相互正交,集中在同一组合分支;意外回归按处置方案提交二分定位。
- **预算:** 共享测试组约 $40,codex ceremony 约 $40,全局回归约 $40–80,micro 约 $5 → Phase 1 约 $150–200,出自活动 $1000 中剩余的约 $850。

## 流程

- 工作在 `codex-efficiency-fixes` worktree(自 `dev` 分出)中进行;依据成文计划,以 subagent-driven-development 方式执行。
- 技能文本改动遵循 writing-skills 方法论。
- 场景/测试台改动(为 Claude Code/Gemini 解除 ceremony 场景门禁、对抗性 micro 简报)按授权落入 `superpowers-evals` main。
- 每个处置方案一个针对 `dev` 的 PR,各附其评测证据与标准标识块;仅在 Jesse 逐 PR 批准后合并。

## Phase 2 队列(基线优先;不属于本计划的任务)

每项都必须先有失败基线,修复才可交付:
1. **派发路由 / 长会话漂移**——需要长会话诱导测试台(CLI 0.146 下全新会话无法复现该病灶)。Drew 的补丁栈为处置形态提供参考。
2. **验证租约 / 证据回执**——需要先给 `score_e3.py` 加入子串感知的重复计数器(当前基线 1/23 精确字符串对太弱)。
3. **修复上限**——小样本基线(2/3 次重复)需要更多重复。
4. **跨任务竞态探针重设计**——`score_e5.py` 的探针因设计取舍而零样本无结论;需要更强的探针。
5. **E5 D4 shell 命令解析器**——修复评审范围分类器无法解析复合命令;属于评分器工作,而非技能工作。

## 范围外

- 采纳 Drew 的 spinout 补丁栈(#2036/#2035)或其文本。
- RoboRev、Codex token 遥测(独立代码库)。
- `close_agent` 卫生检查清单(V2 无此工具——活动中已按"不交付"结案)。
- T4 回归测试组之外的 Claude Code/Gemini 专属效率处置。
