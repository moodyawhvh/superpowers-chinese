> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 可视化头脑风暴重构:浏览器展示,终端命令

**日期:** 2026-02-19
**状态:** 已批准
**范围:** `lib/brainstorm-server/`、`skills/brainstorming/visual-companion.md`、`tests/brainstorm-server/`

## 问题

在可视化头脑风暴期间,Claude 以后台任务方式运行 `wait-for-feedback.sh`,并阻塞在 `TaskOutput(block=true, timeout=600s)` 上。这会完全占用 TUI——可视化头脑风暴运行期间,用户无法向 Claude 输入内容。浏览器成了唯一的输入通道。

Claude Code 的执行模型是基于回合的。单个回合内,Claude 无法同时在两个通道上监听。阻塞式 `TaskOutput` 是错误的原语——它模拟的是平台并不支持的事件驱动行为。

## 设计

### 核心模型

**浏览器 = 交互式展示。** 展示原型图,允许用户点击选择选项。选择结果由服务端记录。

**终端 = 对话通道。** 始终不被阻塞,始终可用。用户在这里与 Claude 交谈。

### 循环

1. Claude 向会话目录写入一个 HTML 文件
2. 服务端通过 chokidar 检测到它,向浏览器推送 WebSocket 重载(保持不变)
3. Claude 结束回合——提示用户查看浏览器并在终端回复
4. 用户查看浏览器,可选择点击某个选项,然后在终端输入反馈
5. 下一回合,Claude 读取 `$SCREEN_DIR/.events` 获取浏览器交互流(点击、选择),并与终端文本合并
6. 迭代或推进

没有后台任务,没有 `TaskOutput` 阻塞,没有轮询脚本。

### 关键删除:`wait-for-feedback.sh`

整体删除。它的存在意义是衔接"服务端把事件记录到 stdout"和"Claude 需要收到这些事件"。`.events` 文件取代了它——服务端直接写入用户交互事件,Claude 用平台提供的任意文件读取机制读取它们。

### 关键新增:`.events` 文件(每屏事件流)

服务端把所有用户交互事件写入 `$SCREEN_DIR/.events`,每行一个 JSON 对象。这让 Claude 拿到当前屏幕的完整交互流——不只是最终选择,还有用户的探索路径(点了 A,又点了 B,最终选定 C)。

用户探索选项后的内容示例:

```jsonl
{"type":"click","choice":"a","text":"Option A - Preset-First Wizard","timestamp":1706000101}
{"type":"click","choice":"c","text":"Option C - Manual Config","timestamp":1706000108}
{"type":"click","choice":"b","text":"Option B - Hybrid Approach","timestamp":1706000115}
```

- 在单个屏幕内只追加。每个用户事件作为新行追加。
- 当 chokidar 检测到新的 HTML 文件(推送了新屏幕)时,该文件被清空(删除),防止过期事件延续到下一屏。
- 如果 Claude 读取时文件不存在,说明没有浏览器交互——Claude 只使用终端文本。
- 文件只包含用户事件(`click` 等)——不包含服务端生命周期事件(`server-started`、`screen-added`)。这样它保持小而专注。
- Claude 可以读取完整交互流来理解用户的探索模式,也可以只看最后一条 `choice` 事件获取最终选择。

## 按文件列出变更

### `index.js`(服务端)

**A. 把用户事件写入 `.events` 文件。**

在 WebSocket `message` 处理器中,把事件记录到 stdout 之后:通过 `fs.appendFileSync` 把该事件作为一行 JSON 追加到 `$SCREEN_DIR/.events`。只写入用户交互事件(带 `source: 'user-event'` 的事件),不写服务端生命周期事件。

**B. 新屏幕出现时清空 `.events`。**

在 chokidar 的 `add` 处理器(检测到新 `.html` 文件)中,若 `$SCREEN_DIR/.events` 存在则删除它。这是最明确的"新屏幕"信号——比在 GET `/` 时清空更好,后者每次重载都会触发。

**C. 替换 `wrapInFrame` 的内容注入。**

当前的正则以 `<div class="feedback-footer">` 为锚点,而该元素将被移除。改用注释占位符:移除 `#claude-content` 内现有的默认内容(`<h2>Visual Brainstorming</h2>` 和副标题段落),替换为单个 `<!-- CONTENT -->` 标记。内容注入变成 `frameTemplate.replace('<!-- CONTENT -->', content)`。更简单,且模板格式变化时也不会坏。

### `frame-template.html`(UI 框架)

**移除:**
- `feedback-footer` div(textarea、Send 按钮、label、`.feedback-row`)
- 相关 CSS(`.feedback-footer`、`.feedback-footer label`、`.feedback-row`、其中的 textarea 和按钮样式)

**新增:**
- `#claude-content` 内的 `<!-- CONTENT -->` 占位符,替换默认文本
- 一个选择指示条,位于原 footer 处,有两种状态:
  - 默认:"Click an option above, then return to the terminal"
  - 选择后:"Option B selected — return to terminal to continue"
- 指示条的 CSS(低调,视觉分量与现有头部相近)

**保持不变:**
- 带有 "Brainstorm Companion" 标题和连接状态的顶栏
- `.main` 包裹层和 `#claude-content` 容器
- 全部组件 CSS(`.options`、`.cards`、`.mockup`、`.split`、`.pros-cons`、占位符、mock 元素)
- 深色/浅色主题变量与媒体查询

### `helper.js`(客户端脚本)

**移除:**
- `sendToClaude()` 函数及 "Sent to Claude" 页面接管
- `window.send()` 函数(原本绑定到被移除的 Send 按钮)
- 表单提交处理器——没有反馈 textarea 后毫无意义,只会增加日志噪音
- 输入变化处理器——同样原因
- `pageshow` 事件监听器(当初为修复 textarea 持久化而加——已经没有 textarea 了)

**保留:**
- WebSocket 连接、重连逻辑、事件队列
- 重载处理器(服务端推送时执行 `window.location.reload()`)
- 用于选择高亮的 `window.toggleSelect()`
- `window.selectedChoice` 跟踪
- `window.brainstorm.send()` 和 `window.brainstorm.choice()`——它们与被移除的 `window.send()` 不同。它们调用 `sendEvent`,通过 WebSocket 记录到服务端。对自定义整页文档有用。

**收窄:**
- 点击处理器:只捕获 `[data-choice]` 点击,不再捕获所有按钮/链接。宽泛捕获在浏览器还是反馈通道时是必要的;现在它只用于选择跟踪。

**新增:**
- 点击 `data-choice` 时,更新选择指示条文本,显示选中了哪个选项。

**从 `window.brainstorm` API 中移除:**
- `brainstorm.sendToClaude`——不再存在

### `visual-companion.md`(技能指令)

**重写 "The Loop" 一节**,改为上述非阻塞流程。删除所有对以下内容的引用:
- `wait-for-feedback.sh`
- `TaskOutput` 阻塞
- 超时/重试逻辑(600 秒超时、30 分钟上限)
- 描述 `send-to-claude` JSON 的 "User Feedback Format" 一节

**替换为:**
- 新循环(写 HTML → 结束回合 → 用户在终端回复 → 读取 `.events` → 迭代)
- `.events` 文件格式文档
- 指引:终端消息是主要反馈;`.events` 提供完整的浏览器交互流作为补充上下文

**保留:**
- 服务端启动/停止说明
- 内容片段与整页文档的区分指引
- CSS 类参考和可用组件
- 设计技巧(保真度与问题匹配、每屏 2-4 个选项等)

### `wait-for-feedback.sh`

**整体删除。**

### `tests/brainstorm-server/server.test.js`

需要更新的测试:
- 断言片段响应中存在 `feedback-footer` 的测试——改为断言选择指示条或 `<!-- CONTENT -->` 替换
- 断言 `helper.js` 含有 `send` 的测试——更新以反映收窄后的 API
- 断言 `sendToClaude` CSS 变量用法的测试——删除(函数已不存在)

## 平台兼容性

服务端代码(`index.js`、`helper.js`、`frame-template.html`)完全平台无关——纯 Node.js 和浏览器 JavaScript,没有任何 Claude Code 专属引用。已经通过后台终端交互在 Codex 上验证可用。

技能指令(`visual-companion.md`)是平台适配层。每个平台的 Claude 使用自己的工具来启动服务端、读取 `.events` 等。非阻塞模型天然跨平台,因为它不依赖任何平台专属的阻塞原语。

## 这带来了什么

- 可视化头脑风暴期间 **TUI 始终可响应**
- **混合输入**——浏览器点击 + 终端输入,自然合并
- **优雅降级**——浏览器挂了或用户没打开?终端照样工作
- **更简单的架构**——没有后台任务、没有轮询脚本、没有超时管理
- **跨平台**——同一套服务端代码可用于 Claude Code、Codex 以及未来的任何平台

## 这放弃了什么

- **纯浏览器反馈流程**——用户必须回到终端才能继续。选择指示条会引导他们,但相比旧的"点击 Send 然后等待"流程多了一步。
- **浏览器内联文本反馈**——textarea 没了。所有文本反馈都走终端。这是有意为之——终端是比框架里一个小 textarea 更好的文本输入通道。
- **浏览器 Send 后立即响应**——旧系统中用户一点 Send Claude 立刻回应。现在用户切换到终端前有一段空隙。实践中只有几秒,而且用户可以在终端消息里补充上下文。
