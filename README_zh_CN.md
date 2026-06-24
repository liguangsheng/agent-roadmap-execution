# Roadmap-Driven Development

中文 | [English](README.md)

一个可移植的 agent skill，用于把多会话的 AI 编程工作组织成 milestone 目录、可执行 sprint 文件、验证证据和每个 sprint 的提交记录。同一份 `SKILL.md` 可以在 **[Codex](https://developers.openai.com/codex/skills)**、**[Claude Code](https://code.claude.com/docs/en/skills)** 和 **[opencode](https://opencode.ai/docs/skills/)** 上通用。

## 用 agent 安装

最快的安装方式是让你的编程 agent 来做。把仓库地址连同类似下面的提示发给 Codex、Claude Code 或 opencode：

> 安装 `roadmap-driven` skill，仓库地址 https://github.com/liguangsheng/roadmap-driven：先检查 `SKILL.md` 和 `agents/openai.yaml`，安装到我的 agent skills 目录，然后验证。

agent 会 clone 仓库、运行 `install.sh`，并确认 `SKILL.md` 和 lint 冒烟测试通过。想自己安装见 [手动安装](#手动安装)。

## 支持的 agent

这个 skill 就是一个包含单个 `SKILL.md`（外加 `scripts/`）的目录。每种支持的工具读取的都是同一份 `SKILL.md`，只是安装目录和调用方式不同。

| Agent | 默认安装目录 | 使用方式 |
| --- | --- | --- |
| [Codex](https://developers.openai.com/codex/skills) | `~/.codex/skills/roadmap-driven` | 显式调用：`$roadmap-driven` |
| [Claude Code](https://code.claude.com/docs/en/skills) | `~/.claude/skills/roadmap-driven` | 按 description 自动发现；让 Claude 使用它即可 |
| [opencode](https://opencode.ai/docs/skills/) | `~/.config/opencode/skills/roadmap-driven` | 按 description 自动发现；让 opencode 使用它即可 |

opencode 也会读取 `~/.claude/skills/`，所以装到 Claude Code 目录后 opencode 同样能用。`agents/openai.yaml` 是 Codex 专用的 UI 元数据，Claude Code 和 opencode 会忽略它。

## 概述

`roadmap-driven` 适合需要暂停、恢复和跨会话延续的代码仓库。它把 roadmap 状态保存在仓库内的 Markdown 文件中，并把每个 sprint 视为一个可验证、可恢复的 AI 编程任务切片。

## 内容

- `SKILL.md`：skill 定义和执行工作流（每种支持的 agent 都会读取）。
- `agents/openai.yaml`：Codex 专用的 UI 元数据，用于 skill 列表和默认调用提示。
- `scripts/roadmap_lint.py`：检查 `.agents/roadmap/` 的结构、状态、链接、Resume Point 和 active sprint 数量。
- `install.sh`：从本地或远程来源把 skill 安装到一个或多个 agent skills 目录，支持复制或符号链接，并自带安装后校验。
- `uninstall.sh`：从已安装的 agent skills 目录中移除这个 skill。

## 手动安装

仓库提供官方 `install.sh`。默认会自动检测已安装的 agent 工具，并为每一个都安装这个 skill；安装后会自动校验 `SKILL.md` 并对 `roadmap_lint.py` 做一次冒烟测试。

克隆后本地安装：

```bash
git clone https://github.com/liguangsheng/roadmap-driven.git
cd roadmap-driven
./install.sh
```

或者一行远程安装（脚本会自动 clone 仓库再安装）：

```bash
curl -fsSL https://raw.githubusercontent.com/liguangsheng/roadmap-driven/main/install.sh | bash
```

用 `--agent` 指定具体的 agent（可重复，或用 `all`）：

```bash
./install.sh --agent claude              # 只装 Claude Code
./install.sh --agent codex --agent opencode
./install.sh --agent all                 # 三个都装，无论是否检测到
```

常用选项：

- `--agent NAME`：为 `codex`、`claude`、`opencode` 或 `all` 安装。可重复。默认自动检测已安装工具（兜底为 `codex`）。
- `--target DIR`：安装到单个指定目录，忽略各 agent 的默认目录。
- `--link`：用符号链接安装，仓库 `git pull` 后立即生效，适合开发迭代。
- `--git URL`：从指定远程仓库 clone 安装。
- `--force`：目标被其他内容占用时强制覆盖。
- `--no-verify`：跳过安装后的校验。
- 运行 `./install.sh --help` 查看完整用法。

可以用 `CODEX_SKILLS_DIR`、`CLAUDE_SKILLS_DIR` 或 `OPENCODE_SKILLS_DIR` 覆盖对应的默认安装目录。

安装完成后，按你所用 agent 的方式使用（见 [支持的 agent](#支持的-agent)）——例如在 Codex 中：

```txt
$roadmap-driven
```

## 卸载

用自带的 `uninstall.sh` 卸载。默认会从所有可能的安装位置（Codex、Claude Code、opencode）移除 `roadmap-driven`：

```bash
./uninstall.sh
```

它只会删除确实是本 skill 的目录（或 `--link` 安装留下的符号链接），不会动无关文件。常用选项：

- `--agent NAME`：限定 `codex`、`claude`、`opencode` 或 `all`。可重复。
- `--target DIR`：移除指定的安装目录。
- `--dry-run`：只预览将删除的内容，不实际删除。
- `--force`：即使目标看起来不像本 skill 也强制删除。

同样支持 `CODEX_SKILLS_DIR` / `CLAUDE_SKILLS_DIR` / `OPENCODE_SKILLS_DIR` 覆盖。

## 新会话恢复

如果项目已经有 `.agents/roadmap/`，并且你希望 agent 从上次暂停的位置继续，建议在新会话的第一句话直接写：

```txt
使用roadmap-driven技能，从 roadmap 的 Resume Point 继续。
```

## 核心约束

- Milestone 表示阶段目标和验收门槛。
- Sprint 表示可执行、可验证、可恢复的任务切片。
- `.agents/roadmap/` 只放 roadmap 控制面文档：根 `README.md`、milestone 目录、milestone `README.md` 和 sprint 文件；规格、设计、报告、发布说明、证据附件等放到 `docs/` 或其他合适位置再链接。
- roadmap 内容只留在 roadmap 目录内：不得在 `.agents/roadmap/` 之外复述 milestone、sprint、状态或 Resume Point；其他文档、代码注释和提交信息只链接到 roadmap，不复制其内容。
- 旧的 `docs/roadmap/` 视为 legacy 路径；重组 roadmap 时迁移到 `.agents/roadmap/`，除非项目明确要求继续使用旧路径。
- 未来 milestone 在拆分成可执行 sprint 文件前保持 `draft`。
- 执行时从第一个非 `done` sprint 恢复，并优先恢复已有的 `in-progress` sprint。
- 执行过程中不得创建新 milestone，除非用户明确要求扩展、重规划、拆分或创建 roadmap 范围。
- 完成的 sprint 必须记录验证证据，并深度审计目标是否真正完成；如有缺口，保持 `in-progress` 并补齐后重新验证和审计。如果项目是 Git 仓库，还必须在进入下一个 sprint 前完成提交。
- 创建、重组或更新 roadmap 状态后，优先运行 `scripts/roadmap_lint.py` 校验结构；如果运行不了，要手动检查同等项目并说明限制。
- `SKILL.md` 末尾附有 **Anti-Patterns**（反模式）自检清单，列出常见失败模式（擅自加 milestone、命令过即当完成、状态不一致……）供执行时对照。
