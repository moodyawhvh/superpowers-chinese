> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# 面向 Claude Code 的跨平台 Polyglot Hooks

Claude Code 插件需要能在 Windows、macOS 和 Linux 上正常工作的 hooks。本文档描述 `hooks/run-hook.cmd` 所采用的单一通用 dispatcher 模式。

> **权威来源:** `hooks/run-hook.cmd` 是标准实现。当本文档与代码不一致时,以代码为准。

## 问题所在

Claude Code 通过 shell 执行 hook 命令:
- **macOS/Linux**:bash 或 sh
- **安装了 Git Bash 的 Windows**:Git Bash
- **未安装 Git Bash 的 Windows**:PowerShell(旧版本使用 CMD.exe)

这两个 Windows 回退 shell 都无法解析我们的命令字符串:PowerShell 会把开头的带引号路径当作字符串表达式,并在随后的裸词处报错;CMD.exe 的 `/c` 引号规则则在路径包含 `(` 这类元字符时剥掉外层引号。因此我们的 hooks 显式声明 `"shell": "bash"`(自 Claude Code 2.1.81 起支持;旧版本会忽略该键),强制走 Git Bash 路线,并在缺少 Git Bash 时给出可操作的"安装 Git for Windows"错误提示,而不是 shell 解析失败。

这带来了几个挑战:

1. **脚本执行**:Windows CMD 无法直接执行 `.sh` 文件
2. **路径格式**:Windows 使用反斜杠(`C:\path`),Unix 使用正斜杠(`/path`)
3. **环境变量**:`$VAR` 语法在 CMD 中不起作用
4. **`.sh` 自动前置**:Windows 上的 Claude Code 会自动给路径中包含 `.sh` 的命令前置 `bash` —— 如果脚本带扩展名,就会干扰 dispatcher

## 解决方案:无扩展名脚本 + 单一通用 Dispatcher

本仓库为所有 hooks 使用一个通用的 `run-hook.cmd` dispatcher。Hook 脚本**不带扩展名**(`session-start`,而不是 `session-start.sh`)。这是有意为之:防止 Claude Code 的 Windows 自动检测机制给 dispatcher 命令前置 `bash` 从而破坏它。

### 文件结构

```
hooks/
├── hooks.json          # 指向 run-hook.cmd,使用无扩展名的脚本名
├── run-hook.cmd        # 跨平台 dispatcher(polyglot 包装器)
└── session-start       # 实际的 hook 逻辑 —— 无扩展名的 bash 脚本
```

### hooks.json

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "shell": "bash",
            "async": false
          }
        ]
      }
    ]
  }
}
```

路径加了引号,因为 `${CLAUDE_PLUGIN_ROOT}` 可能包含空格。

## `run-hook.cmd` 的高层工作原理

`run-hook.cmd` 是一个 polyglot 脚本:Windows 把第一个代码块当作 batch 命令执行,而 Unix shell 把该块视为一个空操作的 heredoc,并继续执行其后的内容。

不要照抄本文档中的实现。修改 dispatcher 时请直接阅读 `hooks/run-hook.cmd`,完成后运行 `tests/hooks/test-session-start.sh`。

### 在 Windows(CMD.exe)上的工作方式

1. batch 段校验脚本名,并根据 dispatcher 自身所在位置解析 hook 目录。
2. 在三个位置尝试 bash:
   - `C:\Program Files\Git\bin\bash.exe`
   - `C:\Program Files (x86)\Git\bin\bash.exe`
   - `PATH` 上的 `bash`(MSYS2、Cygwin,或非默认位置的 Git 安装)
3. 找到 bash 后,从 hooks 目录运行指定名称的无扩展名 hook 脚本。
4. 找不到 bash 时,dispatcher 静默退出(`0`)—— 插件继续工作,只是跳过该 hook。
5. `exit /b` 让 CMD 在到达 Unix 段之前停止。

### 在 Unix(bash/sh)上的工作方式

1. `: << 'CMDBLOCK'` 在一个空操作命令上打开 heredoc。
2. 整个 CMD batch 块被 heredoc 吞掉并忽略。
3. `CMDBLOCK` 之后,bash 解析脚本所在目录,并直接 `exec` 指定的无扩展名脚本。

### 关键设计决策

| 决策 | 原因 |
|------|------|
| 无扩展名脚本 | 防止 Claude Code 的 Windows `.sh` 自动前置机制干扰 dispatcher 命令 |
| 不使用 `-l`(登录 shell) | 没有必要;hook 脚本应当自包含,不依赖登录 shell 的 PATH 设置 |
| 不使用 `cygpath` | bash 直接接收 Windows 路径并能正确处理;旧的 `-c "..."` 调用模式才需要 `cygpath`,直接 exec 不需要 |
| 无 bash 时静默退出 | 避免让未安装 Git for Windows 的用户插件失效;hook 上下文注入会被优雅地跳过 |

## 编写跨平台 Hook 脚本

你的 hook 逻辑放在无扩展名的脚本文件中。几条可移植的写法:

### 应该做
- 尽量使用纯 bash 内建功能
- 用 `$(command)` 代替反引号
- 所有变量展开都加引号:`"$VAR"`

### 应该避免
- 依赖 PATH 中的工具而不提供回退(hook 运行时不带 `-l`,登录 shell 的 PATH 不会被设置)
- 给脚本加 `.sh` 扩展名 —— 这会触发 Claude Code 的 Windows 自动前置

### 示例:不借助外部工具进行 JSON 转义

```bash
escape_for_json() {
    local input="$1"
    local output=""
    local i char
    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        case "$char" in
            $'\\') output+='\\' ;;
            '"') output+='\"' ;;
            $'\n') output+='\n' ;;
            $'\r') output+='\r' ;;
            $'\t') output+='\t' ;;
            *) output+="$char" ;;
        esac
    done
    printf '%s' "$output"
}
```

## 故障排查

### "bash is not recognized"

CMD 在 dispatcher 尝试的三个位置都没有找到 bash。dispatcher 会静默退出(0)而不是报错,因此该 hook 被跳过。请在标准路径安装 Git for Windows,或确保 `bash` 在 `PATH` 上。

### Hook 在 Unix 上正常,但在 Windows 上什么也不做

检查 `hooks.json` 中的脚本文件名是否**无扩展名**。像 `run-hook.cmd session-start.sh` 这样的命令可能触发 Claude Code 的 `.sh` 自动检测,绕过预期的 CMD dispatcher 路径,或者直接尝试运行一个并不存在的 `session-start.sh` 脚本。

### Hook 完全不触发

确认 `hooks.json` 中的 `matcher` 与你的宿主(harness)发出的事件类型匹配。Claude Code 使用 `startup|clear|compact`;Cursor 使用 `sessionStart`。Cursor 变体请查看 `hooks-cursor.json`。

## 相关 Issue

- [anthropics/claude-code#9758](https://github.com/anthropics/claude-code/issues/9758) —— `.sh` 脚本在 Windows 上被编辑器打开
- [anthropics/claude-code#3417](https://github.com/anthropics/claude-code/issues/3417) —— Hooks 在 Windows 上无法工作
