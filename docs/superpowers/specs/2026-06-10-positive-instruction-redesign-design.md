> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 技能指引的正面表述重设计 — 设计规格

**状态:** 提案(2026-06-09 SDD 评审分发工作的后续;按"一个 PR 只解决一个问题"的规则单独立 PR)
**驱动因素:** 2026-06-10 的实测证据表明,技能文本中的部分否定式指令会适得其反,另一些则有效——而且两者的差异是可以预测的。

## 本规格所泛化的实测发现

2026-06-10 的微测试(opus,每种表述 5 次重复,程序化评分;工具链见下文)测量了指引措辞如何改变控制器生成的内容:

| 案例 | 表述 | 结果 |
|---|---|---|
| 分发撰写("don't restate the brief") | 禁止式 | 重打了 **4.4** 个规格值——*比不给指引*(3.6)*更糟* |
| 分发撰写 | 正面配方("your dispatch should contain: (1)…(5)") | **3.0,零方差**——采纳 |
| 分发撰写 | 配方 + 细则条款("quote only the fragment…") | 3.8,有噪音——细则会稀释配方 |
| 测试重跑指令("do not ask reviewer to re-run tests") | 禁止式 | **0/5 违例**——有效(对照组:3/5) |
| 测试重跑指令 | 正面配方 | 0/5——效果相当,但更长 |

**判定准则**(用它对任何否定式指令分类):

1. **绊线有效。** 针对具体 token 的短语级自检("如果你正在写的提示词包含 'do not flag'……停下")触发可靠。
2. **识别表有效。** Red-Flags/合理化借口表要在决策时刻阅读,而不是撰写时刻。
3. **离散式指令禁止有效。** "Do not ask X to do Y" 在模型没有做 Y 的竞争性动机时成立。
4. **撰写类禁止会适得其反**——当模型对输出自有意图时(例如重述规格让人感觉是在贴心整理)。只有正面的撰写配方能改变这类行为——而且给已验证的配方追加细则条款只会更糟,不会更好。
5. **平局取更短者。** Codex 在一次长会话中会重读 SKILL.md 约 500 次(2026-06-10 实测);文本长度是真实成本。

## 审计结果(2026-06-10,全部约 30 个技能 + 提示词模板)

统计:3 处绊线(保留),14 张识别表(保留),约 20 处策略门(保留——"never push without permission" 是策略,不是撰写塑形),5 处撰写类禁止:

| # | 位置 | 处置 |
|---|---|---|
| 1 | `subagent-driven-development/task-reviewer-prompt.md` — "Cite, don't narrate" | **已排入 PR #1717 批次**:保留正面部分并前置("Your report should point at evidence: file:line for every finding…"),删除禁止部分(死重——正面部分已存在并承担全部作用) |
| 2 | `subagent-driven-development/SKILL.md` — "Do not add open-ended directives" | **保持原样**:微测试在 15 个样本中未能诱发该失败;双向都没有证据;更短者胜 |
| 3 | `subagent-driven-development/SKILL.md` — "Do not ask a reviewer to re-run tests" | **保持原样**:实测 0/5 违例;该禁止还能有效地自行传播进分发内容 |
| 4 | `subagent-driven-development/SKILL.md` — "do not re-review on top of it" | **已排入 PR #1717 批次**:替换为三要素清单("Before re-dispatching the reviewer, confirm the fix report contains: the covering tests, the command run, and the output") |
| 5 | `writing-plans/SKILL.md` — "No Placeholders" 违禁模式列表 | **本规格的主要对象**——见下文 |

边缘情况,与 #5 一并延后处理:`task-reviewer-prompt.md` 的 "Don't flag pre-existing file sizes — focus on what this change contributed"(正面部分已存在且承担作用;影响低;方便的话可与 #5 一起测试)。

## writing-plans 变更(延后项 #5)

### 现状

`skills/writing-plans/SKILL.md` 的 "No Placeholders":一句正面表述("Every step must contain the actual content an engineer needs"),后接六条违禁模式列表("never write them: 'TBD', 'TODO', 'Add appropriate error handling', 'Write tests for the above', 'Similar to Task N', …")。

### 为什么重要,以及为什么确实存在不确定性

- 计划是工作流中**最大的生成产物**,而模型有真实的竞争动机去输出占位符(在长度压力下,那是最省力的路径)——这正是禁止式被实测证明适得其反的案例的动机结构。
- 但违禁项是**离散、可识别的 token**——这正是禁止式被实测证明有效的案例的形状。
- **该列表在其他地方承担作用:** 该技能的 Self-Review 一节引用了它("Placeholder scan: search your plan for red flags — any of the patterns from the 'No Placeholders' section above")。这些 token 同时充当评审期的扫描清单,而评审期识别正是有效的类别。天真地换成正面清单会破坏该引用,并丢弃有效的绊线 token。

### 待测试的变体

- **V0(现状):** 撰写时给正面句子 + 违禁列表;Self-Review 引用该列表。
- **V1(审计者清单):** 撰写时只给正面配方——"Before finalizing a step, confirm it has: the literal code to write, a runnable command with expected output, types and method names defined within this plan, error handling shown explicitly. A step is complete when an engineer could implement it without asking any follow-up questions." Self-Review 保留通用的占位符扫描。
- **V2(按机制重构——预测的赢家):** 撰写时只给 V1 的正面配方;命名模式整体迁移到 Self-Review 的占位符扫描步骤,重新表述为识别("when you scan, look for: 'TBD', 'TODO', 'Similar to Task N', …")。同样的 token,从"诱发"类别搬到"检测"类别。
- **V3(对照):** 只给正面句子,任何地方都不给列表。

### 微测试设计

- **任务:** opus 根据一份刻意欠规定的规格撰写一份 2-3 任务的实现计划(欠规定正是诱发占位符的因素)。使用包含以下内容的固定规格:一个规定良好的任务、一个错误处理被含糊带过的任务、一个与第一个相似的任务(诱发 "Similar to Task 1")。
- **采样:** 每个变体 5+ 次重复,默认温度,模型 `claude-opus-4-8`(实践中写计划的模型)。
- **程序化评分**(除注明外,越低越好):
  - 违禁 token 计数:`TBD|TODO|implement later|fill in details|appropriate error handling|handle edge cases|Similar to Task|Write tests for the above`
  - 涉及代码变更却没有围栏代码块的步骤数
  - 引用了计划输出中任何地方都未定义的类型/函数
  - (越高越好)每个任务带预期输出的可运行命令数
- **V2 的两阶段评分:** 同时测试 Self-Review 部分——把每份生成的计划连同该变体的 Self-Review 一节回喂,测量扫描是否真能捕获植入的占位符(向固定计划插入 2 个已知占位符;检测率为指标)。
- **验收标准:** 只有在违禁 token 计数上胜过 V0,且不损失代码块覆盖率或自审检测率时,才采纳某个变体。预计成本:总计约 $6-10。

### PR 范围

单独的 PR(writing-plans 是另一个技能;其 "No Placeholders" 列表属于调优内容,贡献者指南要求提供评测证据)。PR 必须包含:微测试工具链 + 结果表、修改前后的文本,以及 V2 迁移的理由。

## 微测试工具链(记录方法,以免失传)

`/tmp/sdd-exp/micro/run-micro.py` 与 `/tmp/sdd-exp/micro2/run-micro2.py`
(2026-06-10;待提交到 superpowers-evals,作为
`docs/superpowers/skills/micro-testing-prompt-guidance.md` + 脚本):

- 每个样本一次 API 调用:system = 处于真实上下文中的技能指引变体;user = 一个真实的中途工作流场景;输出 = 生成的产物(分发提示词、计划、报告)。
- 程序化评分,用 grep 找无歧义标记;**在采信结论前人工核查每一条匹配**——今晚的某个"违例"其实是控制器正确引用了禁止条文,另一个则被自动否定检测贴错了标签。
- 每样本约 $0.15-0.30,每次迭代几秒,相比之下完整评测一轮 $12/50 分钟。措辞在这里迭代;只有结构性变化才去完整跑一遍确认赢家。
- 始终包含一个无指引对照组——今晚正是它同时揭示了适得其反的禁止(重述:禁止比什么都不给更糟)和有效的禁止(测试重跑:对照组 3/5 失败,两种表述下均为 0/5)。

## 结果:writing-plans 微测试(2026-06-10 运行,在本规格写完之后)

**已解决——无需变更。** 阶段 1(3 任务规格,无压力):四个变体连同无指引对照组,全部 20 份计划中 0 个占位符。阶段 1b(10 任务规格,五个几乎相同的命令诱发 "Similar to Task N",明确的约 2,500 词篇幅目标):40/40 干净——唯一的正则命中是某个 V2 自审在*声明*"no TBD/TODO ✓"。当前一代 opus 即使在刻意压力下也不会产出计划占位符,无论有无违禁模式列表。处置:No Placeholders 一节原样保留(成本极低,而反事实无法测量);不要开后续 PR。V2 迁移设计留档于此,以备未来模型世代出现退化。

## 同样明确不删除的项(已测试并否决,附数据)

记录在案,防止没有新证据就有人重新提议——完整数字见 2026-06-09 SDD 设计规格的 Cost-iterations 一节:

- **控制器回合批处理 / 单消息并行工具调用:** 控制器每条消息恰好发出一次工具调用(所有实测运行中,无论有无指引,均为 0 条多工具消息)。46% 的控制器回合是没有任何工具调用的思考/叙述——这是一个对提示词免疫的底值。
- **通过并行调用做流水线评审:** 出于同样原因已死。
- **通过 `run_in_background` 做流水线评审:** 机制在被提供时会被采用(28 次分发中 7 次),但在 45 分钟场景上收益低于运行间噪音底值(每次评审仅约 30-60 秒);还引入双结果流协调。只有当计划的各次评审单独耗时很长时才值得重新考虑。
- **给已验证配方追加细则条款:** 实测会劣化配方(C2:3.8 有噪音 vs C:3.0 稳定)。迭代方式是重新推导配方,而不是追加注意事项。
