---
name: roadmap-driven
description: Use when a user wants an AI coding agent to plan, organize, or execute multi-session roadmap work using `.agents/roadmap` milestone directories, executable sprint files, validation evidence, and per-sprint commits; applies to roadmap structure, milestone/sprint mapping, draft vs planned status, implementation sequencing, pause/resume handoffs, and keeping project plans, docs, and execution evidence aligned.
---

# Roadmap-Driven Development

Use this skill to structure and drive a project through a tree-shaped roadmap where milestones define completion gates and sprints define executable work.

This workflow borrows milestone and sprint terminology, but does not implement Scrum. Here, a sprint means an executable, verifiable, resumable work package for an AI coding agent.

Use it for multi-step, multi-session, or roadmap-driven work. Do not create roadmap structure for trivial one-shot fixes unless the user asks.

When this skill's bundled scripts are available, use `scripts/roadmap_lint.py` to check roadmap structure after creating, reorganizing, or updating roadmap status. If the script is unavailable or Python cannot run, perform the same checks manually and record the limitation.

The default roadmap root is `.agents/roadmap/`. Treat `docs/roadmap/` as a legacy location unless the user or repository explicitly opts into it.

## Core Model

```txt
roadmap   = the milestone tree that plans and tracks the project
milestone = phase goal and acceptance gate
sprint    = executable task checklist
```

A roadmap owns milestones, and a milestone owns sprints. A sprint must live under the milestone it serves, and every milestone under the roadmap root `.agents/roadmap/`. The roadmap is the single source of truth for project direction and execution state.

Recommended layout:

```txt
.agents/roadmap/
  README.md
  M00-short-name/
    README.md
    S000-first-sprint.md
  M01-short-name/
    README.md
    S001-next-sprint.md
```

`.agents/roadmap/` is only for roadmap control-plane documents: the root `README.md`, milestone directories, milestone `README.md` files, and sprint files named like `Sxxx-*.md`. Do not create or keep specifications, grammar docs, design docs, reports, release notes, implementation plans, evidence artifacts, status docs, feature profiles, or other auxiliary documents under `.agents/roadmap/`; put them elsewhere such as `docs/` or another appropriate project directory and link to them from the relevant milestone or sprint.

Keep roadmap content inside the roadmap tree. Do not restate roadmap content—milestone goals, sprint tasks and checklists, statuses, Resume Points, or the milestone/sprint breakdown—outside `.agents/roadmap/`. Other documents, code comments, and commit messages may link or point to the roadmap location, but must not duplicate or paraphrase what it contains, so the tree stays the single source of truth and outside docs cannot drift from it.

If old flat `milestones.md`, `PLAN.md`, `sprints/`, legacy `docs/roadmap/`, or other non-roadmap files exist, treat them as migration sources only. Move roadmap control-plane content into `.agents/roadmap/` when reorganizing, move non-roadmap content outside `.agents/roadmap/`, then make the tree the authority.

## Milestone Creation Guard

- Do not create new milestones, extend milestone numbering, or add future milestone README files unless the user explicitly asks to create, expand, replan, or split milestones/roadmap.
- Execution requests such as "continue", "resume", "推进下一个 sprint", "按 roadmap 执行", "fix this", or "finish the current milestone" are not permission to add milestones.
- During execution, if new future work is discovered, record it in the current sprint Evidence/Notes, the current milestone Open Questions, or an existing backlog if one already exists. If no appropriate place exists, report it to the user and ask before changing roadmap scope.
- Updating existing milestone/sprint status, evidence, links, Resume Point, or sprint tables for the work already selected is allowed; creating a new milestone is a separate planning action requiring explicit user intent.

## Decision Handling

Decisions arise constantly during execution; route them by impact.

- Significant decisions — ask the user first. Pause before acting when a choice is hard to reverse, changes scope or roadmap structure, selects an architecture, API, data model, or dependency, affects security or user-facing behavior, or resolves an ambiguous requirement. Present the options with a recommendation; do not guess.
- Small decisions — decide autonomously, correctness first. For low-impact, reversible choices (naming, local structure, test layout, obvious defaults), pick the most correct option that fits the codebase and proceed without blocking. Favor correctness and consistency over convenience.
- Record either way. Capture autonomous decisions and their rationale in the current sprint Evidence (`Decisions`), and milestone-level decisions in the milestone `Decisions` section, so the reasoning is durable and resumable. A decision that changes roadmap scope still requires the Milestone Creation Guard's explicit user intent.

## Status Rules

Use these milestone statuses consistently:

- `draft`: milestone has a README only; direction exists but executable sprint breakdown is missing.
- `planned`: milestone has at least one executable sprint with tasks, tests, commands, and Done criteria.
- `in-progress`: at least one sprint is actively being executed.
- `done`: required sprints and milestone acceptance criteria are complete and verified.

Do not mark a README-only milestone as `planned`.

Use these sprint statuses consistently:

- `planned`: sprint is executable but has not started.
- `in-progress`: sprint is currently being worked.
- `blocked`: sprint cannot continue without a decision, missing dependency, or failing prerequisite.
- `done`: sprint Done criteria, validation commands, and completion audit have passed.

Milestone status derives from sprint state:

- all sprints `planned` -> milestone `planned`;
- any sprint `in-progress` or `blocked` -> milestone `in-progress`;
- all required sprints `done` and acceptance criteria pass -> milestone `done`.

## Roadmap README

Create or update `.agents/roadmap/README.md` with:

- status definitions;
- milestone table linking to each `Mxx-*/README.md`;
- tracking rules;
- sprint status rules for pause/resume;
- rule that future milestones remain `draft` until split into sprint files;
- completion rule: sprint Done criteria, validation commands, completion audit, and milestone acceptance criteria must all pass.
- lint rule: run the roadmap lint script when available after roadmap structure or status changes.

## Milestone README Template

Each milestone directory must have `README.md`:

```markdown
# Mxx: Title

Status: draft|planned|in-progress|done

## Goal

...

## Scope

- ...

## Sprint Status

| Sprint | Status | Notes |
| --- | --- | --- |
| [Sxxx-name.md](Sxxx-name.md) | planned | ... |

## Resume Point

Start at the first sprint whose status is not `done`. If one is `in-progress`, resume there before starting later sprints.

## Acceptance Criteria

- ...

## Open Questions

- ...

## Decisions

- ...

## Out of Scope

- ...
```

If there are no sprint files yet, set status to `draft` and write “Split when the previous milestone is close to done.”

## Sprint Template

Each sprint file must be directly executable:

````markdown
# Sxxx: Title

Milestone: Mxx Title.
Status: planned|in-progress|blocked|done

## Goal

...

## Preconditions

- ...

## Files

- ...

## Tasks

- [ ] ...

## Tests

- ...

## Validation Commands

```txt
...
```

## Evidence

- Validation:
- Completion audit:
- Commit:
- Decisions:
- Notes:

## Done Criteria

- ...

## Out of Scope

- ...
````

The sprint `Status:` line is recommended for new sprint files. Existing roadmaps may keep status only in the milestone sprint table, but when both exist they must agree.

## Completion Audit Checklist

Before marking a sprint `done`, verify and record each item:

- Goal: the implemented behavior satisfies the sprint Goal, not only adjacent tasks.
- Tasks: every checked task is actually implemented; incomplete tasks remain unchecked or are explicitly moved out of scope.
- Done Criteria: each criterion has direct evidence.
- Validation Commands: required commands ran, or the Evidence explains why a command could not run and what substituted for it.
- Changed files: all agent-owned edits are relevant to the sprint; unrelated user changes remain untouched.
- Milestone Acceptance Criteria: the sprint result advances or satisfies the owning milestone gate as expected.
- Out of Scope: no excluded work was silently pulled into the sprint.
- Evidence: validation, audit result, notes, and blockers are recorded in the sprint file or linked artifact.
- Decisions: significant choices were raised with the user before acting; autonomous choices and their rationale are recorded in the sprint.
- Commit: in Git repositories, the completed sprint has its own commit before later sprint work begins.

## Operating Workflow

Choose the mode from the user's request before editing:

- plan/reorganize: create or reshape roadmap structure only when the user asks for planning, setup, reorganization, expansion, or splitting.
- execute: continue from the current `Resume Point`, prefer the active `in-progress` sprint, and avoid changing roadmap scope.
- recover/audit: when the user reports drift, missing work, or questionable completion, inspect current evidence before changing statuses.
- inspect/report: when the user asks for status, summarize roadmap state without editing unless the request clearly asks for fixes.

When asked to plan or reorganize:

1. Inspect existing docs and tree first.
2. Identify the authoritative planning surface.
3. Confirm the request explicitly permits roadmap expansion before creating any new milestone.
4. If flat milestones/sprints or legacy `docs/roadmap/` files exist, migrate to `.agents/roadmap/Mxx-*/` only when the user asked for roadmap setup or reorganization.
5. Keep long-range milestones as `draft` unless they have executable sprints.
6. Split only the next actionable milestone into sprint files.
7. Keep non-roadmap content out of `.agents/roadmap/`; move specs, designs, reports, release notes, feature profiles, and evidence attachments to non-roadmap docs and link them from milestones or sprints.
8. Update all links in README, implementation plans, and compatibility docs.
9. Verify no stale paths remain with `rg`.
10. Run `python <skill-dir>/scripts/roadmap_lint.py <repo-root>` when available; otherwise manually check for invalid statuses, broken links, misplaced files, multiple active sprints, and Resume Point drift.

When asked to execute:

1. Start from the current milestone README.
2. If the project is in a Git repository, run `git status -sb` before selecting or editing a sprint. Distinguish pre-existing user changes from agent-owned changes, and do not overwrite unrelated user work.
3. Find the first sprint whose status is not `done`; prefer an existing `in-progress` sprint over later planned sprints.
4. Mark the selected sprint `in-progress` before editing code.
5. Do not add new milestones while executing; unexpected future work should be noted or reported, not turned into roadmap scope without explicit user approval.
6. Execute sprint tasks in order.
7. Update checklist status as work completes.
8. Run validation commands.
9. Run the completion audit checklist before marking the sprint `done`. Confirm the implemented behavior actually satisfies the stated target, not just that commands passed.
10. If the audit finds gaps, keep the sprint `in-progress`, record the gap in Evidence/Notes or unchecked tasks, implement the missing work, rerun affected validation, and repeat the completion audit.
11. Record validation and completion-audit results in the sprint Evidence section.
12. Mark sprint `done` only when Done criteria, validation, and completion audit pass. Keep the sprint file `Status:` and milestone sprint table consistent when both exist.
13. Update the owning milestone sprint status table.
14. Mark milestone `done` only when every required sprint is done and acceptance criteria pass.
15. Run `python <skill-dir>/scripts/roadmap_lint.py <repo-root>` when available after status changes.
16. If the project is in a Git repository, commit immediately after each sprint is marked `done`, before starting the next sprint. Keep generated build outputs out of the commit, use a commit message that names the completed sprint or milestone slice, and record the commit hash in the sprint Evidence section or milestone sprint table.

When pausing or handing off:

1. Leave the current sprint as `in-progress` unless it is truly blocked or done.
2. Record the next concrete task in the milestone README `Resume Point` or sprint notes.
3. Keep validation evidence in the sprint file or a referenced evidence artifact.
4. If blocked, record the exact blocker, failed command or output summary, last safe state, and smallest user decision or external dependency needed.
5. Do not advance later sprint statuses speculatively.

## Quality Gates

- Milestone acceptance criteria answer “what proves this phase is complete?”
- Sprint Done criteria answer “what proves this task slice is complete?”
- A milestone can be directionally useful as `draft`, but it is not executable until `planned`.
- A milestone README must track sprint status so work can pause and resume without reconstructing context from chat.
- Avoid detailed sprint planning for far-future milestones; it drifts before execution.
- Prefer repo-local docs and checklists over chat-only plans.
- Treat validation as necessary but not sufficient: each sprint must pass a target-focused completion audit before it is done, and any discovered gap must be closed inside that sprint unless it is explicitly out of scope or blocked.
- For Git-backed projects, sprint completion is not fully durable until the verified sprint changes are committed separately from later sprint work.

## Anti-Patterns

Common failure modes to self-check against; each points back to the governing rule.

- Structuring trivial work: a roadmap for a one-shot fix the user didn't ask to plan. → Use the roadmap only for multi-step/multi-session work.
- Polluting the tree: specs, designs, reports, or evidence under `.agents/roadmap/`. → Keep only control-plane docs there; link out (see Core Model).
- Leaking roadmap content: restating milestones/sprints/statuses/Resume Points outside the tree. → Link to the roadmap, never duplicate it (see Core Model).
- Unrequested milestones: adding milestones on a "continue"/"resume"/"按 roadmap 执行" request. → Creating milestones needs explicit user intent (see Milestone Creation Guard).
- Premature `planned`: marking a README-only milestone `planned`. → `planned` needs at least one executable sprint (see Status Rules).
- Status drift: the sprint `Status:` line and the milestone sprint table disagree. → Keep both consistent when both exist (see Sprint Template).
- Validation-as-done: marking a sprint `done` because commands passed, without auditing the goal. → Pass the completion audit; close gaps inside the sprint (see Completion Audit Checklist).
- Speculative status: advancing later sprints before working them. → Only the active sprint is `in-progress` (see When pausing or handing off).
- Overwriting user work: editing unrelated pre-existing changes during a sprint. → Separate agent edits from user changes; leave user work untouched (see When asked to execute).
- Far-future detail: writing detailed sprints for distant milestones. → Keep them `draft`; split only the next actionable milestone (see Quality Gates).
- Uncommitted completion: starting the next sprint before committing the finished one in Git repositories. → Commit each done sprint separately first (see Quality Gates).
- Silent big decision: making a hard-to-reverse, scope-, architecture-, or security-affecting choice without asking. → Ask the user first with options and a recommendation; record the resolution (see Decision Handling).
- Blocking on trivia: asking the user about a low-impact, reversible choice. → Decide it correctness-first, proceed, and record it (see Decision Handling).
