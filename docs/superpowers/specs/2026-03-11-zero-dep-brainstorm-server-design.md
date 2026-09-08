> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 零依赖 Brainstorm 服务器

用单个零依赖的 `server.js`(只用 Node.js 内置模块)替换 brainstorm 伴随服务器中内嵌的 node_modules(express、ws、chokidar —— 714 个受跟踪文件)。

## 动机

把 node_modules 内嵌进 git 仓库会带来供应链风险:被冻结的依赖拿不到安全补丁,714 个第三方代码文件未经审计就提交入库,对内嵌代码的修改看起来和普通提交无异。虽然实际风险很低(仅限 localhost 的开发服务器),但消除它并不麻烦。

## 架构

单个 `server.js` 文件(约 250-300 行),只用 `http`、`crypto`、`fs` 和 `path`。该文件承担两种角色:

- **直接运行时**(`node server.js`):启动 HTTP/WebSocket 服务器
- **被 require 时**(`require('./server.js')`):导出 WebSocket 协议函数供单元测试使用

### WebSocket 协议

仅针对文本帧实现 RFC 6455:

**握手:** 用 SHA-1 加 RFC 6455 魔术 GUID,从客户端的 `Sec-WebSocket-Key` 计算 `Sec-WebSocket-Accept`。返回 101 Switching Protocols。

**帧解码(客户端到服务器):** 处理三种带掩码的长度编码:
- 小:payload < 126 字节
- 中:126-65535 字节(16 位扩展)
- 大:> 65535 字节(64 位扩展)

用 4 字节掩码密钥对 payload 做 XOR 去掩码。返回 `{ opcode, payload, bytesConsumed }`;缓冲不完整时返回 `null`。拒绝未掩码的帧。

**帧编码(服务器到客户端):** 不带掩码的帧,使用相同的三种长度编码。

**处理的 opcode:** TEXT(0x01)、CLOSE(0x08)、PING(0x09)、PONG(0x0A)。未识别的 opcode 会收到状态码 1003(Unsupported Data)的关闭帧。

**有意跳过:** 二进制帧、分片消息、扩展(permessage-deflate)、子协议。对 localhost 客户端之间的小型 JSON 文本消息而言这些并无必要。扩展与子协议在握手中协商——只要不宣告它们,就永远不会启用。

**缓冲累积:** 每个连接维护一个缓冲区。收到 `data` 时追加内容并循环调用 `decodeFrame`,直到它返回 null 或缓冲区清空。

### HTTP 服务器

三条路由:

1. **`GET /`** —— 按 mtime 提供 screen 目录中最新的 `.html` 文件。区分完整文档与片段,把片段包进框架模板,并注入 helper.js。返回 `text/html`。当不存在 `.html` 文件时,提供一个硬编码的等待页("Waiting for Claude to push a screen..."),同样注入 helper.js。
2. **`GET /files/*`** —— 从 screen 目录提供静态文件,MIME 类型通过硬编码的扩展名映射(html、css、js、png、jpg、gif、svg、json)查询。找不到时返回 404。
3. **其余所有路径** —— 404。

WebSocket 升级通过 HTTP 服务器的 `'upgrade'` 事件处理,与请求处理器相互独立。

### 配置

环境变量(全部可选):

- `BRAINSTORM_PORT` —— 绑定端口(默认:49152-65535 范围内的随机高位端口)
- `BRAINSTORM_HOST` —— 绑定的网络接口(默认:`127.0.0.1`)
- `BRAINSTORM_URL_HOST` —— 启动 JSON 中 URL 使用的主机名(host 为 `127.0.0.1` 时默认 `localhost`,否则与 host 相同)
- `BRAINSTORM_DIR` —— screen 目录路径(默认:`/tmp/brainstorm`)

### 启动流程

1. 若 `SCREEN_DIR` 不存在则创建(`mkdirSync` 递归)
2. 从 `__dirname` 加载框架模板和 helper.js
3. 在配置的 host/port 上启动 HTTP 服务器
4. 对 `SCREEN_DIR` 启动 `fs.watch`
5. 监听成功后,向 stdout 记录 `server-started` JSON:`{ type, port, host, url_host, url, screen_dir }`
6. 把同一份 JSON 写入 `SCREEN_DIR/.server-info`,让 agent 在 stdout 不可见(后台执行)时也能找到连接信息

### 应用层 WebSocket 消息

收到客户端的 TEXT 帧时:

1. 按 JSON 解析。解析失败则记录到 stderr 并继续。
2. 以 `{ source: 'user-event', ...event }` 的形式记录到 stdout。
3. 若事件包含 `choice` 属性,则把该 JSON 追加到 `SCREEN_DIR/.events`(每个事件一行)。

### 文件监视

`fs.watch(SCREEN_DIR)` 取代 chokidar。对 HTML 文件事件:

- 新文件(`rename` 事件且文件存在):若 `.events` 文件存在则删除(`unlinkSync`),并以 JSON 形式向 stdout 记录 `screen-added`
- 文件变更(`change` 事件):以 JSON 形式向 stdout 记录 `screen-updated`(**不要**清除 `.events`)
- 两种事件都要:向所有已连接的 WebSocket 客户端发送 `{ type: 'reload' }`

按文件名做约 100ms 的防抖,避免重复事件(macOS 和 Linux 上很常见)。

### 错误处理

- WebSocket 客户端发来格式错误的 JSON:记录到 stderr,继续
- 未处理的 opcode:以状态 1003 关闭
- 客户端断开:从广播集合中移除
- `fs.watch` 错误:记录到 stderr,继续
- 没有优雅关闭逻辑 —— shell 脚本通过 SIGTERM 管理进程生命周期

## 变更内容

| 之前 | 之后 |
|---|---|
| `index.js` + `package.json` + `package-lock.json` + 714 个 `node_modules` 文件 | `server.js`(单文件) |
| express、ws、chokidar 依赖 | 无 |
| 无静态文件服务 | `/files/*` 从 screen 目录提供文件 |

## 保持不变

- `helper.js` —— 不变
- `frame-template.html` —— 不变
- `start-server.sh` —— 一行改动:`index.js` 改为 `server.js`
- `stop-server.sh` —— 不变
- `visual-companion.md` —— 不变
- 所有现有服务器行为与对外契约

## 平台兼容性

- `server.js` 只使用跨平台的 Node 内置模块
- 对单一扁平目录,`fs.watch` 在 macOS、Linux 和 Windows 上都可靠
- Shell 脚本需要 bash(Windows 上为 Git Bash,而 Claude Code 本身也要求它)

## 测试

**单元测试**(`ws-protocol.test.js`):通过 require `server.js` 的导出,直接测试 WebSocket 帧编解码、握手计算以及协议边界情况。

**集成测试**(`server.test.js`):测试完整的服务器行为——HTTP 服务、WebSocket 通信、文件监视、brainstorm 工作流。使用 `ws` npm 包作为仅测试用的客户端依赖(不交付给最终用户)。
