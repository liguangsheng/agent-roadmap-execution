# Roadmap-Driven Development

English | [中文](README_zh_CN.md)

A portable agent skill for planning and executing multi-session AI coding work with milestone directories, executable sprint files, validation evidence, and per-sprint commits. One `SKILL.md` works across **[Codex](https://developers.openai.com/codex/skills)**, **[Claude Code](https://code.claude.com/docs/en/skills)**, and **[opencode](https://opencode.ai/docs/skills/)**.

## Install With an Agent

The quickest way to install is to let your coding agent do it. Hand the repository URL to Codex, Claude Code, or opencode with a prompt like:

> Install the `roadmap-driven` skill from
> https://github.com/liguangsheng/roadmap-driven: inspect `SKILL.md`
> and `agents/openai.yaml`, install it into my agent's skills directory, then verify.

The agent clones the repository, runs `install.sh`, and confirms `SKILL.md` and the lint smoke test pass. To install it yourself, see [Manual Install](#manual-install).

## Supported Agents

The skill is a directory with a single `SKILL.md` (plus `scripts/`). Every supported tool reads the same `SKILL.md`; only the install directory and invocation differ.

| Agent | Default install dir | How to use it |
| --- | --- | --- |
| [Codex](https://developers.openai.com/codex/skills) | `~/.codex/skills/roadmap-driven` | invoke explicitly: `$roadmap-driven` |
| [Claude Code](https://code.claude.com/docs/en/skills) | `~/.claude/skills/roadmap-driven` | auto-discovered by description; ask Claude to use it |
| [opencode](https://opencode.ai/docs/skills/) | `~/.config/opencode/skills/roadmap-driven` | auto-discovered by description; ask opencode to use it |

opencode also reads `~/.claude/skills/`, so a Claude Code install already makes the skill available in opencode. `agents/openai.yaml` is Codex-only UI metadata; Claude Code and opencode ignore it.

## Overview

`roadmap-driven` is designed for repositories where work needs to be paused and resumed without reconstructing context from chat. It keeps roadmap state in repo-local Markdown files and treats every sprint as a verifiable, resumable work package for an AI coding agent.

## Contents

- `SKILL.md`: the skill definition and operating workflow (read by every supported agent).
- `agents/openai.yaml`: Codex-only UI metadata for skill lists and default invocation.
- `scripts/roadmap_lint.py`: checks `.agents/roadmap/` structure, statuses, links, Resume Point text, and active sprint count.
- `install.sh`: installs the skill into one or more agent skills directories from a local or remote source, via copy or symlink, with a built-in post-install verification.

## Manual Install

The repository ships an official `install.sh`. By default it auto-detects which agent tools are installed and installs the skill for each of them; after copying it verifies `SKILL.md` and runs a `roadmap_lint.py` smoke test.

Install from a local clone:

```bash
git clone https://github.com/liguangsheng/roadmap-driven.git
cd roadmap-driven
./install.sh
```

Or a one-line remote install (the script clones the repository for you):

```bash
curl -fsSL https://raw.githubusercontent.com/liguangsheng/roadmap-driven/main/install.sh | bash
```

Choose specific agents with `--agent` (repeatable, or `all`):

```bash
./install.sh --agent claude              # Claude Code only
./install.sh --agent codex --agent opencode
./install.sh --agent all                 # all three, whether or not detected
```

Common options:

- `--agent NAME`: install for `codex`, `claude`, `opencode`, or `all`. Repeatable. Default: auto-detect installed tools (fallback: `codex`).
- `--target DIR`: install into a single explicit directory, ignoring the per-agent defaults.
- `--link`: install as a symlink so a `git pull` in the source takes effect immediately; handy for development.
- `--git URL`: clone and install from the given remote repository.
- `--force`: overwrite a target even when it holds unrelated files.
- `--no-verify`: skip the post-install verification.
- Run `./install.sh --help` for the full reference.

Override any default install directory with `CODEX_SKILLS_DIR`, `CLAUDE_SKILLS_DIR`, or `OPENCODE_SKILLS_DIR`.

After installation, use it per your agent (see [Supported Agents](#supported-agents)) — for example in Codex:

```txt
$roadmap-driven
```

## Resuming in a New Session

If the project already has `.agents/roadmap/` and you want the agent to continue from where it paused, open a new session with:

```txt
Use the roadmap-driven skill and continue from the roadmap Resume Point.
```

## What It Enforces

- Milestones represent phase goals and acceptance gates.
- Sprints represent executable, verifiable, resumable task slices.
- `.agents/roadmap/` contains only roadmap control-plane documents: the root `README.md`, milestone directories, milestone `README.md` files, and sprint files. Put specs, designs, reports, release notes, evidence attachments, and other auxiliary docs elsewhere under `docs/` or another appropriate project directory and link to them.
- Legacy `docs/roadmap/` is treated as a migration source. Reorganize roadmap files into `.agents/roadmap/` unless the repository explicitly opts into the old path.
- Future milestones stay `draft` until split into executable sprint files.
- Execution resumes from the first non-`done` sprint, preferring an existing `in-progress` sprint.
- New milestones are not created during execution unless the user explicitly asks to expand, replan, split, or create roadmap scope.
- Completed sprints must record validation evidence and pass a deep completion audit of the stated goal. If gaps remain, keep the sprint `in-progress`, close the gaps, then rerun validation and the audit. In Git repositories, commit before moving to the next sprint.
- After creating, reorganizing, or updating roadmap status, run `scripts/roadmap_lint.py` when available. If it cannot run, manually check the same items and state the limitation.
