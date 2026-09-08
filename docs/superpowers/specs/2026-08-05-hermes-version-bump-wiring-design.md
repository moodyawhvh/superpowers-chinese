> 🌐 本文档由 [obra/superpowers](https://github.com/obra/superpowers) 翻译,英文原版见原项目。

# Hermes 版本号联动设计

**日期:** 2026-08-05
**修订:** 2026-08-06
**状态:** 已批准

## 目标

通过把 `.hermes-plugin/plugin.yaml` 登记进 `.version-bump.json`,并让 `scripts/bump-version.sh` 学会处理 YAML(而不必在 Bash 里实现一个 YAML 解析器),使其与仓库版本保持同步。

## 设计

- 在 `.version-bump.json` 中加入 `{ "path": ".hermes-plugin/plugin.yaml", "field": "version" }`。
- `.json` 走现有的 `jq` 辅助函数,`.yaml` 走 Mike Farah 的 `yq` v4。YAML 的键与值作为数据传入,不拼接进表达式。
- 只支持存在的顶层 YAML 字符串字段。嵌套字段与 `.yml` 不在范围内。
- `--check`、`--audit` 与版本更新都经由同一个小型读/写分发器。
- 在版本更新写入任何 manifest 之前,先运行一次只读 preflight,校验所需工具,并通过分发器读取每一个存在的已声明 manifest。这样可以避免前面的 JSON 文件已经更新之后才出现确定性的 YAML 失败。文件缺失时的行为保持不变,没有 `jq` 或 `yq` 时 `--help` 仍可使用。

preflight 是唯一新增的可靠性措施。它不会让脚本变成事务式,也不会重构现有的 audit 与错误状态行为。

## 测试

三个聚焦行为的测试用真实脚本对隔离的临时 fixture 运行,并证明:

- 对齐的 JSON 与 YAML 能通过 `--check` 和 `--audit`,且一次 bump 会同时更新两种格式;
- 真实执行一次 bump,当 JSON 声明在前、后面跟着一个顶层 `version` 不是字符串的 YAML manifest 时,脚本以非零码退出,且每个 manifest 逐字节保持不变;
- 真实的 `.version-bump.json` 已登记 Hermes manifest。

验证还会对仓库运行 shell lint 和 `scripts/bump-version.sh --check`。

## 非目标

- 不手写 YAML 解析器。
- 不支持 `.yml` 或嵌套 YAML。
- 不改动 Hermes 运行时。
- 不做回滚框架、通用配置 schema 层、audit/status 重构,或穷举式失败矩阵。
- 不改动评审中发现的另一个独立的版本校验与 JSON 表达式问题。
