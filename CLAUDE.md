# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A **Claude Code skills repository** — a collection of reusable Agent Skills that can be loaded into Claude Code sessions. The bulk of the project is the skills themselves, not application code. There is no build, lint, or test step.

## Repository layout

```
.
├── skills/                        # Custom (first-party) skills
│   └── <skill-name>/
│       ├── SKILL.md               # Required: skill definition with YAML frontmatter
│       ├── references/            # Optional: supporting docs (templates, schemas, ...)
│       └── scripts/               # Optional: helper scripts invoked from the skill
├── .agents/skills/                # Vendored skills mirrored from external sources
│   ├── grill-with-docs/
│   ├── review/
│   └── write-a-skill/
├── skills-lock.json               # Lockfile for vendored skills (source + content hash)
└── LICENSE                        # MIT (Copyright 2026 Gaara)
```

- `skills/` — first-party skills authored in this repo. The current example is `weekly-report`.
- `.agents/skills/` — vendored copies of skills pulled from upstream (e.g. `mattpocock/skills` on GitHub). These are managed via `skills-lock.json`; do not edit them by hand, since changes will be overwritten on the next sync.
- `skills-lock.json` — declares `source`, `sourceType` (e.g. `github`), `sourcePath`, and a `computedHash` of the upstream file for each vendored skill. Update it when adding/upgrading a vendored skill.

## Authoring a skill (first-party)

Each skill is a directory under `skills/<skill-name>/` containing at minimum a `SKILL.md` with YAML frontmatter:

```markdown
---
name: <kebab-case-name>
description: <one-paragraph description — must include trigger phrases the user is likely to say>
---

# <Skill Title>

<Body: workflow, inputs, mapping tables, output format, examples.>
```

Conventions observed in this repo:
- Skill names use **kebab-case**.
- `description` is the trigger — enumerate the user's likely phrasings (English + Chinese for the existing skills). This is what the Skill tool's auto-suggestion uses to decide relevance.
- Long-form references go in `references/` and are linked from `SKILL.md` (see `weekly-report/references/template.md`).
- Helper scripts go in `scripts/`. They should be `bash` with `set -euo pipefail`, accept `--help`, and emit a machine-parseable format documented in `SKILL.md`. The existing `extract_commits.sh` is the reference example — note its portable-Monday computation and its `=== META === / === COMMITS ===` framing.
- The skill body should explicitly tell the model how to interpret script output (parsing rules, edge cases, what to leave blank for the user to fill in).

## Vendored skills (`.agents/skills/`)

The three skills under `.agents/skills/` are pinned in `skills-lock.json` to specific commits/files in `mattpocock/skills`. To upgrade or replace one:

1. Update the entry in `skills-lock.json` (new `sourcePath`, new `computedHash`).
2. Replace the directory contents under `.agents/skills/<name>/` to match the upstream version.
3. Commit both changes together.

Do **not** hand-edit files inside `.agents/skills/` — the next sync will clobber them.

## The `weekly-report` skill (current first-party skill)

Generates a Chinese technical weekly report from a developer's git commits in a given time range.

- **Trigger phrases** (from `description`): 写周报, 本周周报, 生成周报, 周报模版, weekly report, 本周工作总结.
- **Inputs**: `--author` (required, git name or email), `--since` / `--until` (default Mon 00:00 → today 23:59), `--path` (default cwd).
- **Pipeline**: `scripts/extract_commits.sh` → parse `=== META === / === COMMITS ===` blocks → group `feat` commits by scope into §1.1, count other conventional-commit types into §1.2, leave subjective sections (§1.3, §2.x, §3, §4.x, §5) as template text with a prompt for the user to fill in.
- **The Conventional-Commit → section mapping table** lives in `SKILL.md` (under "Commit Type → 周报章节 映射"). Edit there if the section taxonomy changes.
- The full report layout, including the `[AUTO]` / `[TODO]` markers, is in `references/template.md`. The agent must keep `[TODO]` sections verbatim and only replace content inside `[AUTO]` sections.
