#!/usr/bin/env bash
#
# sync-to-codex-plugin.sh
#
# 将本 superpowers 检出同步 → prime-radiant-inc/openai-codex-plugins。
# 在临时目录中全新克隆该 fork,rsync 上游已跟踪的插件内容
# (包括提交在 .codex-plugin/ 和 assets/ 下的 Codex 文件),保留
# 目标插件中已有的 OpenAI 所属市场元数据,然后提交、
# 推送同步分支,并创建 PR。
# 与路径/用户无关 —— 从脚本所在位置自动检测上游。
#
# 确定性:对同一上游 SHA 运行两次会产出 diff 完全相同的 PR,
# 因此连续两次运行即可验证工具本身的行为。
#
# Usage:
#   ./scripts/sync-to-codex-plugin.sh                              # 完整执行
#   ./scripts/sync-to-codex-plugin.sh -n                           # 试运行
#   ./scripts/sync-to-codex-plugin.sh -y                           # 跳过确认
#   ./scripts/sync-to-codex-plugin.sh --local PATH                 # 使用现有检出
#   ./scripts/sync-to-codex-plugin.sh --base BRANCH                # 默认: main
#   ./scripts/sync-to-codex-plugin.sh --bootstrap                  # 插件目录缺失时创建
#
# Bootstrap 模式:跳过"插件必须已存在于 base 分支"的要求,并在缺失时
# 创建 plugins/superpowers/,然后像普通同步一样从上游复制已跟踪的
# 插件文件。
#
# Requires: bash, rsync, git, gh (authenticated), python3.

set -euo pipefail

# =============================================================================
# 配置 —— 随上游或标准插件结构的演进而修改
# =============================================================================

FORK="prime-radiant-inc/openai-codex-plugins"
DEFAULT_BASE="main"
DEST_REL="plugins/superpowers"

# 上游中不应进入内嵌插件的路径。
# 所有模式都以 "/" 开头,锚定到源根目录。
# 未锚定的模式(如 "scripts/")会匹配任意深度下任何名为
# "scripts" 的目录 —— 包括像 skills/brainstorming/scripts/ 这样的
# 合法嵌套目录。锚定可以避免这种情况。
# (.DS_Store 特意不锚定 —— Finder 到处都会生成它。)
EXCLUDES=(
  # 点文件与基础设施 —— 仅限顶层
  "/.claude/"
  "/.claude-plugin/"
  "/.codex/"
  "/.cursor-plugin/"
  "/.devin-plugin/"
  "/.git/"
  "/.gitattributes"
  "/.github/"
  "/.gitignore"
  "/.gitmodules"
  "/.kimi-plugin/"
  "/.opencode/"
  "/.pi/"
  "/.pre-commit-config.yaml"
  "/.version-bump.json"
  "/.worktrees/"
  ".DS_Store"

  # 根目录的约定性文件
  "/AGENTS.md"
  "/CHANGELOG.md"
  "/CLAUDE.md"
  "/GEMINI.md"
  "/RELEASE-NOTES.md"
  "/gemini-extension.json"
  "/package.json"

  # 标准 Codex 插件不随附的目录
  "/commands/"
  "/docs/"
  "/evals/"
  "/lib/"
  "/scripts/"
  "/tests/"
  "/tmp/"
)

# =============================================================================
# 被忽略路径的辅助函数
# =============================================================================

IGNORED_DIR_EXCLUDES=()

path_has_directory_exclude() {
  local path="$1"
  local dir

  if [[ ${#IGNORED_DIR_EXCLUDES[@]} -eq 0 ]]; then
    return 1
  fi

  for dir in "${IGNORED_DIR_EXCLUDES[@]}"; do
    [[ "$path" == "$dir"* ]] && return 0
  done

  return 1
}

ignored_directory_has_tracked_descendants() {
  local path="$1"

  [[ -n "$(git -C "$UPSTREAM" ls-files --cached -- "$path/")" ]]
}

append_git_ignored_directory_excludes() {
  local path
  local lookup_path

  while IFS= read -r -d '' path; do
    [[ "$path" == */ ]] || continue

    lookup_path="${path%/}"
    if ! ignored_directory_has_tracked_descendants "$lookup_path"; then
      IGNORED_DIR_EXCLUDES+=("$path")
      RSYNC_ARGS+=(--exclude="/$path")
    fi
  done < <(git -C "$UPSTREAM" ls-files --others --ignored --exclude-standard --directory -z)
}

append_git_ignored_file_excludes() {
  local path

  while IFS= read -r -d '' path; do
    path_has_directory_exclude "$path" && continue
    RSYNC_ARGS+=(--exclude="/$path")
  done < <(git -C "$UPSTREAM" ls-files --others --ignored --exclude-standard -z)
}

# =============================================================================
# 参数
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE="$DEFAULT_BASE"
DRY_RUN=0
YES=0
LOCAL_CHECKOUT=""
BOOTSTRAP=0

usage() {
  sed -n '/^# Usage:/,/^# Requires:/s/^# \{0,1\}//p' "$0"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)  DRY_RUN=1; shift ;;
    -y|--yes)      YES=1; shift ;;
    --local)       LOCAL_CHECKOUT="$2"; shift 2 ;;
    --base)        BASE="$2"; shift 2 ;;
    --bootstrap)   BOOTSTRAP=1; shift ;;
    -h|--help)     usage 0 ;;
    *)             echo "Unknown arg: $1" >&2; usage 2 ;;
  esac
done

# =============================================================================
# 预检查
# =============================================================================

die() { echo "ERROR: $*" >&2; exit 1; }

command -v rsync >/dev/null   || die "rsync not found in PATH"
command -v git >/dev/null     || die "git not found in PATH"
command -v gh >/dev/null      || die "gh not found — install GitHub CLI"
command -v python3 >/dev/null || die "python3 not found in PATH"

gh auth status >/dev/null 2>&1 || die "gh not authenticated — run 'gh auth login'"

[[ -d "$UPSTREAM/.git" ]]         || die "upstream '$UPSTREAM' is not a git checkout"
[[ -f "$UPSTREAM/.codex-plugin/plugin.json" ]] || die "committed Codex manifest missing at $UPSTREAM/.codex-plugin/plugin.json"

# 从已提交的 Codex 清单中读取上游版本号。
UPSTREAM_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$UPSTREAM/.codex-plugin/plugin.json")"
[[ -n "$UPSTREAM_VERSION" ]] || die "could not read 'version' from committed Codex manifest"

UPSTREAM_BRANCH="$(cd "$UPSTREAM" && git branch --show-current)"
UPSTREAM_SHA="$(cd "$UPSTREAM" && git rev-parse HEAD)"
UPSTREAM_SHORT="$(cd "$UPSTREAM" && git rev-parse --short HEAD)"

confirm() {
  [[ $YES -eq 1 ]] && return 0
  read -rp "$1 [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

if [[ "$UPSTREAM_BRANCH" != "main" ]]; then
  echo "WARNING: upstream is on '$UPSTREAM_BRANCH', not 'main'"
  confirm "Sync from '$UPSTREAM_BRANCH' anyway?" || exit 1
fi

UPSTREAM_STATUS="$(cd "$UPSTREAM" && git status --porcelain)"
if [[ -n "$UPSTREAM_STATUS" ]]; then
  echo "WARNING: upstream has uncommitted changes:"
  echo "$UPSTREAM_STATUS" | sed 's/^/  /'
  echo "Sync will use working-tree state, not HEAD ($UPSTREAM_SHORT)."
  confirm "Continue anyway?" || exit 1
fi

# =============================================================================
# 准备目标仓库(全新克隆 fork,或使用 --local)
# =============================================================================

CLEANUP_DIR=""
cleanup() {
  if [[ -n "$CLEANUP_DIR" ]]; then
    rm -rf "$CLEANUP_DIR"
  fi
}
trap cleanup EXIT

if [[ -n "$LOCAL_CHECKOUT" ]]; then
  DEST_REPO="$(cd "$LOCAL_CHECKOUT" && pwd)"
  [[ -d "$DEST_REPO/.git" ]] || die "--local path '$DEST_REPO' is not a git checkout"
else
  echo "Cloning $FORK..."
  CLEANUP_DIR="$(mktemp -d)"
  DEST_REPO="$CLEANUP_DIR/openai-codex-plugins"
  gh repo clone "$FORK" "$DEST_REPO" >/dev/null
fi

DEST="$DEST_REPO/$DEST_REL"
PREVIEW_REPO="$DEST_REPO"
PREVIEW_DEST="$DEST"
SYNC_SOURCE=""

overlay_destination_paths() {
  local repo="$1"
  local path
  local source_path
  local preview_path

  while IFS= read -r -d '' path; do
    source_path="$repo/$path"
    preview_path="$PREVIEW_REPO/$path"

    if [[ -e "$source_path" ]]; then
      mkdir -p "$(dirname "$preview_path")"
      cp -R "$source_path" "$preview_path"
    else
      rm -rf "$preview_path"
    fi
  done
}

copy_local_destination_overlay() {
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" diff --name-only -z -- "$DEST_REL"
  )
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" diff --cached --name-only -z -- "$DEST_REL"
  )
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" ls-files --others --exclude-standard -z -- "$DEST_REL"
  )
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" ls-files --others --ignored --exclude-standard -z -- "$DEST_REL"
  )
}

local_checkout_has_uncommitted_destination_changes() {
  [[ -n "$(git -C "$DEST_REPO" status --porcelain=1 --untracked-files=all --ignored=matching -- "$DEST_REL")" ]]
}

prepare_preview_checkout() {
  if [[ -n "$LOCAL_CHECKOUT" ]]; then
    [[ -n "$CLEANUP_DIR" ]] || CLEANUP_DIR="$(mktemp -d)"
    PREVIEW_REPO="$CLEANUP_DIR/preview"
    git clone -q --no-local "$DEST_REPO" "$PREVIEW_REPO"
    PREVIEW_DEST="$PREVIEW_REPO/$DEST_REL"
  fi

  git -C "$PREVIEW_REPO" checkout -q "$BASE" 2>/dev/null || die "base branch '$BASE' doesn't exist in $FORK"
  if [[ -n "$LOCAL_CHECKOUT" ]]; then
    copy_local_destination_overlay
  fi
  if [[ $BOOTSTRAP -ne 1 ]]; then
    [[ -d "$PREVIEW_DEST" ]] || die "base branch '$BASE' has no '$DEST_REL/' — use --bootstrap, or pass --base <branch>"
  fi
}

prepare_apply_checkout() {
  git -C "$DEST_REPO" checkout -q "$BASE" 2>/dev/null || die "base branch '$BASE' doesn't exist in $FORK"
  if [[ $BOOTSTRAP -ne 1 ]]; then
    [[ -d "$DEST" ]] || die "base branch '$BASE' has no '$DEST_REL/' — use --bootstrap, or pass --base <branch>"
  fi
}

apply_to_preview_checkout() {
  if [[ $BOOTSTRAP -eq 1 ]]; then
    mkdir -p "$PREVIEW_DEST"
  fi

  rsync "${RSYNC_ARGS[@]}" "$SYNC_SOURCE/" "$PREVIEW_DEST/"
}

preview_checkout_has_changes() {
  [[ -n "$(git -C "$PREVIEW_REPO" status --porcelain "$DEST_REL")" ]]
}

prepare_preview_checkout

TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
if [[ $BOOTSTRAP -eq 1 ]]; then
  SYNC_BRANCH="bootstrap/superpowers-${UPSTREAM_SHORT}-${TIMESTAMP}"
else
  SYNC_BRANCH="sync/superpowers-${UPSTREAM_SHORT}-${TIMESTAMP}"
fi

# =============================================================================
# 构建 rsync 参数
# =============================================================================

RSYNC_ARGS=(-av --delete --delete-excluded)
for pat in "${EXCLUDES[@]}"; do RSYNC_ARGS+=(--exclude="$pat"); done
append_git_ignored_directory_excludes
append_git_ignored_file_excludes

copy_preserved_destination_metadata() {
  local destination="$1"
  local source="$2"
  local path
  local rel

  [[ -d "$destination/skills" ]] || return 0

  while IFS= read -r -d '' path; do
    rel="${path#"$destination"/}"
    mkdir -p "$source/$(dirname "$rel")"
    cp -p "$path" "$source/$rel"
  done < <(find "$destination/skills" -path '*/agents/openai.yaml' -type f -print0)
}

prepare_sync_source() {
  local destination="$1"

  [[ -n "$CLEANUP_DIR" ]] || CLEANUP_DIR="$(mktemp -d)"

  SYNC_SOURCE="$CLEANUP_DIR/source-overlay"
  rm -rf "$SYNC_SOURCE"
  mkdir -p "$SYNC_SOURCE"

  rsync "${RSYNC_ARGS[@]}" "$UPSTREAM/" "$SYNC_SOURCE/" >/dev/null
  copy_preserved_destination_metadata "$destination" "$SYNC_SOURCE"
}

prepare_sync_source "$PREVIEW_DEST"

# =============================================================================
# 试运行预览(始终显示)
# =============================================================================

echo ""
echo "Upstream: $UPSTREAM ($UPSTREAM_BRANCH @ $UPSTREAM_SHORT)"
echo "Version:  $UPSTREAM_VERSION"
echo "Fork:     $FORK"
echo "Base:     $BASE"
echo "Branch:   $SYNC_BRANCH"
if [[ $BOOTSTRAP -eq 1 ]]; then
  echo "Mode:     BOOTSTRAP (creating plugins/superpowers/ when absent)"
fi
echo ""
echo "=== Preview (rsync --dry-run) ==="
rsync "${RSYNC_ARGS[@]}" --dry-run --itemize-changes "$SYNC_SOURCE/" "$PREVIEW_DEST/"
echo "=== End preview ==="
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo ""
  echo "Dry run only. Nothing was changed or pushed."
  exit 0
fi

# =============================================================================
# 应用
# =============================================================================

echo ""
confirm "Apply changes, push branch, and open PR?" || { echo "Aborted."; exit 1; }

echo ""
if [[ -n "$LOCAL_CHECKOUT" ]]; then
  if local_checkout_has_uncommitted_destination_changes; then
    die "local checkout has uncommitted changes under '$DEST_REL' — commit, stash, or discard them before syncing"
  fi

  apply_to_preview_checkout
  if ! preview_checkout_has_changes; then
    echo "No changes — embedded plugin was already in sync with upstream $UPSTREAM_SHORT (v$UPSTREAM_VERSION)."
    exit 0
  fi
fi

prepare_apply_checkout
cd "$DEST_REPO"
git checkout -q -b "$SYNC_BRANCH"
echo "Syncing upstream content..."
if [[ $BOOTSTRAP -eq 1 ]]; then
  mkdir -p "$DEST"
fi
rsync "${RSYNC_ARGS[@]}" "$SYNC_SOURCE/" "$DEST/"

# 若实际没有任何变化则提前退出
cd "$DEST_REPO"
if [[ -z "$(git status --porcelain "$DEST_REL")" ]]; then
  echo "No changes — embedded plugin was already in sync with upstream $UPSTREAM_SHORT (v$UPSTREAM_VERSION)."
  exit 0
fi

# =============================================================================
# 提交、推送、创建 PR
# =============================================================================

git add "$DEST_REL"

if [[ $BOOTSTRAP -eq 1 ]]; then
  COMMIT_TITLE="bootstrap superpowers v$UPSTREAM_VERSION from upstream main @ $UPSTREAM_SHORT"
  PR_BODY="Initial bootstrap of the superpowers plugin from upstream \`main\` @ \`$UPSTREAM_SHORT\` (v$UPSTREAM_VERSION).

Creates \`plugins/superpowers/\` by copying the tracked plugin files from upstream, including \`.codex-plugin/plugin.json\`, \`assets/\`, and \`hooks/\`.

Run via: \`scripts/sync-to-codex-plugin.sh --bootstrap\`
Upstream commit: https://github.com/obra/superpowers/commit/$UPSTREAM_SHA

This is a one-time bootstrap. Subsequent syncs will be normal (non-bootstrap) runs using the same tracked upstream plugin files."
else
  COMMIT_TITLE="sync superpowers v$UPSTREAM_VERSION from upstream main @ $UPSTREAM_SHORT"
  PR_BODY="Automated sync from superpowers upstream \`main\` @ \`$UPSTREAM_SHORT\` (v$UPSTREAM_VERSION).

Copies the tracked plugin files from upstream, including the committed Codex manifest, assets, and hooks.

Run via: \`scripts/sync-to-codex-plugin.sh\`
Upstream commit: https://github.com/obra/superpowers/commit/$UPSTREAM_SHA

Running the sync tool again against the same upstream SHA should produce a PR with an identical diff — use that to verify the tool is behaving."
fi

git commit --quiet -m "$COMMIT_TITLE

Automated sync via scripts/sync-to-codex-plugin.sh
Upstream: https://github.com/obra/superpowers/commit/$UPSTREAM_SHA
Branch:   $SYNC_BRANCH"

echo "Pushing $SYNC_BRANCH to $FORK..."
git push -u origin "$SYNC_BRANCH" --quiet

echo "Opening PR..."
PR_URL="$(gh pr create \
  --repo "$FORK" \
  --base "$BASE" \
  --head "$SYNC_BRANCH" \
  --title "$COMMIT_TITLE" \
  --body "$PR_BODY")"

PR_NUM="${PR_URL##*/}"
DIFF_URL="https://github.com/$FORK/pull/$PR_NUM/files"

echo ""
echo "PR opened: $PR_URL"
echo "Diff view: $DIFF_URL"
