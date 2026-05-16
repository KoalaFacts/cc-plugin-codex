# cc-plugin-codex

A Codex CLI plugin that exposes [Claude Code](https://docs.claude.com/en/docs/claude-code/overview)
(`claude -p`) as a set of delegated skills inside Codex — plan, implement,
execute, review, rescue, and setup. The mirror of `codex-plugin-cc`, which
goes the other direction.

## Why

Codex and Claude Code are good at different things. Sometimes you're
deep in a Codex session and want a second-opinion review from Claude
before you merge. Sometimes Codex is stuck and you want Claude to take
over. Sometimes you just want Claude to plan a task and let Codex
implement it. This plugin makes those handoffs one-line invocations
inside Codex.

## Install

In your shell (not inside a Codex session):

```bash
# 1. Add this repo as a Codex marketplace.
codex plugin marketplace add KoalaFacts/cc-plugin-codex

# 2. Install the plugin from that marketplace.
codex plugin add cc-plugin-codex@cc-plugin-codex
```

Then inside Codex:

```text
/plugins         # confirm cc-plugin-codex is installed and enabled
```

Run `/claude:setup` (or `$claude-setup`) to verify your `claude` CLI is
installed, authenticated, and healthy.

### Prerequisites

- [Codex CLI](https://github.com/openai/codex) **v0.131 or newer** —
  earlier builds don't have the `codex plugin` subcommand. Check with
  `codex --version`; update with `npm i -g @openai/codex@latest` or your
  installer's equivalent.
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/quickstart)
  on `PATH`, authenticated. Install:
  - macOS / Linux: `npm i -g @anthropic-ai/claude-code`
  - Windows: `irm https://claude.ai/install.ps1 | iex`

## Skills

| Skill              | What it does                                                                  |
| ------------------ | ----------------------------------------------------------------------------- |
| `claude-setup`     | Verify `claude` on PATH, run `claude doctor`, smoke-test a tiny prompt.       |
| `claude-plan`      | Read-only: return an implementation plan for a task. No files written.        |
| `claude-implement` | Spec-to-patch. Default writes to `.handoff/claude.patch`; `--apply` writes inline. |
| `claude-execute`   | Full agent loop — plan + implement + verify + iterate.                        |
| `claude-review`    | Review the current `git diff`. Supports `--evil` and `--experts <list>`.      |
| `claude-rescue`    | Hand the current Codex task + transcript to Claude when Codex is stuck.       |

### `claude-review` flags

- `--base <ref>` — diff against `<ref>...HEAD` (default `HEAD`).
- `--evil` (alias `--adversarial`) — adversarial reviewer persona.
- `--experts <list>` — comma-separated reviewer personas. Available:
  `default`, `evil`, `security`, `perf`, `api-design`. The plugin runs
  one Claude pass per persona, then a synthesis pass that produces a
  consensus.

Examples:

```text
ask claude to review
ask claude to review --base origin/main
ask claude to review --evil
ask claude to review --experts security,perf
ask claude to review --evil --experts security,api-design
```

## Transport: CLI primary, MCP optional

Every skill in this plugin shells out to `claude -p` for one-shot,
agentic invocations that return a single JSON result. This is the
recommended path — fast, low token overhead, full control over flags
(`--max-turns`, `--append-system-prompt-file`,
`--dangerously-skip-permissions`).

`.mcp.json` ships an **optional** MCP server registration
(`claude mcp serve`) for users who want Codex to access Claude's Bash /
Read / Write / Edit / Grep / Glob / LS tools as per-tool MCP round
trips. Most users don't need this; enable it in your Codex MCP config
only if you have a specific reason.

## Repo layout

```text
cc-plugin-codex/
├── .claude-plugin/marketplace.json       # marketplace manifest at repo root
├── plugins/
│   └── cc-plugin-codex/                  # the plugin lives in a subdir
│       ├── .codex-plugin/plugin.json     # plugin manifest
│       ├── skills/                       # six SKILL.md files
│       │   ├── claude-setup/
│       │   ├── claude-plan/
│       │   ├── claude-implement/
│       │   ├── claude-execute/
│       │   ├── claude-review/
│       │   └── claude-rescue/
│       ├── personas/                     # reviewer system prompts
│       │   ├── default.md
│       │   ├── evil.md
│       │   ├── security.md
│       │   ├── perf.md
│       │   └── api-design.md
│       ├── system-prompts/               # appended for plan / implement / execute
│       │   ├── planner.md
│       │   ├── implementer.md
│       │   └── executor.md
│       └── .mcp.json                     # optional MCP fallback
├── scripts/Test-Plugin.ps1               # smoke test
├── PLAN.md                               # design plan
└── README.md
```

The marketplace manifest at the root references the plugin via
`source: "./plugins/cc-plugin-codex"`, matching the layout pattern
`anthropics/claude-plugins-official` uses (plugins always in subdirs).

## Smoke test

```text
pwsh ./scripts/Test-Plugin.ps1           # static checks
pwsh ./scripts/Test-Plugin.ps1 -E2E      # also exercise `claude -p`
```

Static checks verify the layout and manifest parse. `-E2E` requires
`claude` on PATH and exercises a real one-shot review call against a
temporary fixture repo.

## Conventions

- Skills write intermediates to `.handoff/` in the consuming repo.
  Consumers should `.gitignore` this directory.
- The plugin never auto-commits. Patches and changes are always for
  the user to review.
- `--dangerously-skip-permissions` is used by `claude-implement`,
  `claude-execute`, and `claude-rescue` because the delegating Codex
  session has already taken on responsibility for the task — second
  prompts would be noise. `claude-plan` and `claude-review` do **not**
  use it (read-only).

## Status

v0.1. Skills are stable in shape but lightly battle-tested. Issues
welcome on the GitHub repo.

## License

MIT. See `LICENSE`.
