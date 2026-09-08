/**
 * OpenCode.ai 的 Superpowers 插件
 *
 * 通过消息变换(message transform)注入 superpowers 引导(bootstrap)上下文。
 * 通过 config 钩子自动注册 skills 目录(无需符号链接)。
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// 简单的 frontmatter 提取(引导流程避免依赖 skills-core)
const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };

  const frontmatterStr = match[1];
  const body = match[2];
  const frontmatter = {};

  for (const line of frontmatterStr.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');
      frontmatter[key] = value;
    }
  }

  return { frontmatter, content: body };
};

// 规范化路径:去除首尾空白,展开 ~,解析为绝对路径
const normalizePath = (p, homeDir) => {
  if (!p || typeof p !== 'string') return null;
  let normalized = p.trim();
  if (!normalized) return null;
  if (normalized.startsWith('~/')) {
    normalized = path.join(homeDir, normalized.slice(2));
  } else if (normalized === '~') {
    normalized = homeDir;
  }
  return path.resolve(normalized);
};

// 引导内容的模块级缓存。
// SKILL.md 文件在会话期间不会变化,因此只需读取并解析一次,
// 即可省去每个 agent 步骤中重复的 fs.existsSync + fs.readFileSync
// 和正则处理。完整分析参见 #1202。
let _bootstrapCache = undefined; // undefined = 尚未加载,null = 文件缺失

export const SuperpowersPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();
  const superpowersSkillsDir = path.resolve(__dirname, '../../skills');
  const envConfigDir = normalizePath(process.env.OPENCODE_CONFIG_DIR, homeDir);
  const configDir = envConfigDir || path.join(homeDir, '.config/opencode');

  // 生成引导内容的辅助函数(首次调用后缓存)
  const getBootstrapContent = () => {
    // 后续调用直接返回缓存结果
    if (_bootstrapCache !== undefined) return _bootstrapCache;

    // 尝试加载 using-superpowers 技能
    const skillPath = path.join(superpowersSkillsDir, 'using-superpowers', 'SKILL.md');
    if (!fs.existsSync(skillPath)) {
      _bootstrapCache = null;
      return null;
    }

    const fullContent = fs.readFileSync(skillPath, 'utf8');
    const { content } = extractAndStripFrontmatter(fullContent);

    const toolMapping = `**Tool Mapping for OpenCode:**
When skills request actions, substitute OpenCode equivalents:
- Create or update todos → \`todowrite\`
- \`Subagent (general-purpose):\` → \`task\` with \`subagent_type: "general"\`
- Invoke a skill → OpenCode's native \`skill\` tool
- Read files → \`read\`
- Create, edit, or delete files → \`apply_patch\`
- Run shell commands → \`bash\`
- Search files → \`grep\`, \`glob\`
- Fetch a URL → \`webfetch\`

Use OpenCode's native \`skill\` tool to list and load skills.`;

    _bootstrapCache = `<EXTREMELY_IMPORTANT>
You have superpowers.

**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT use the skill tool to load "using-superpowers" again - that would be redundant.**

${content}

${toolMapping}
</EXTREMELY_IMPORTANT>`;

    return _bootstrapCache;
  };

  return {
    // 将 skills 路径注入运行时配置,让 OpenCode 无需手动符号链接
    // 或修改配置文件即可发现 superpowers 技能。
    // 之所以可行,是因为 Config.get() 返回的是缓存的单例 —— 这里的修改
    // 在之后惰性发现技能时是可见的。
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(superpowersSkillsDir)) {
        config.skills.paths.push(superpowersSkillsDir);
      }
    },

    // 将引导内容注入每个会话的第一条用户消息。
    // 使用用户消息而非系统消息可以避免:
    //   1. 系统消息每轮重复导致的 token 膨胀 (#750)
    //   2. 多条系统消息破坏 Qwen 及其他模型 (#894)
    //
    // 该钩子在每个 agent 步骤都会触发(而不只是每一轮),因为
    // opencode 的 prompt.ts 每一步都会从数据库重新加载消息。新的消息
    // 数组可能需要再次注入,因此 getBootstrapContent() 不能
    // 做重复的磁盘操作。
    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;
      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      // 防护:若第一条用户消息已包含引导内容则跳过。
      // 这可以防止 OpenCode 把已经转换过的内存中消息数组再次
      // 传入钩子时发生重复注入。
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    }
  };
};
