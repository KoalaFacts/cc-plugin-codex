# cc-plugin-codex — Plan

## Context

The repo `cc-plugin-codex` is empty (just `.gitignore` + `LICENSE`). The goal
is a **Codex CLI plugin** that exposes Claude Code (`claude -p`) as a
delegated tool — the mirror of `codex-plugin-cc` (which goes Claude →
Codex). OpenAI shipped a real Codex plugin format
(`.codex-plugin/plugin.json`, with skills / hooks / MCP / marketplace) and
there's no official Anthropic build for the reverse direction, so the slot
is open. Name: `cc-plugin-codex`.

## Recommended approach

A v0.1 Codex plugin **named `cc-plugin-codex`** with six skills
(plan / implement / execute / review / rescue / setup), a manifest, an
optional MCP fallback, and a GitHub-repo install loop. Defer hooks,
background-job elegance, and streaming until v0.2.

### Skills (v0.1)

The plugin gives Codex the full Claude Code surface, not just review:

| Skill              | Trigger                                       | Purpose                                                                  |
| ------------------ | --------------------------------------------- | ------------------------------------------------------------------------ |
| `claude-setup`     | `/claude:setup`                               | Verify `claude` on PATH, run `claude doctor`, offer installer            |
| `claude-plan`      | "ask claude to plan", `/claude:plan`          | Read-only: returns an implementation plan for a task (no writes)         |
| `claude-implement` | "ask claude to implement", `/claude:implement`| Writes code from a spec/task description (writes files, no verify loop)  |
| `claude-execute`   | "ask claude to do X", `/claude:execute`       | Full agent loop: plan + implement + run tests + verify                   |
| `claude-review`    | "ask claude to review", `/claude:review`      | Reviews `git diff`; flags select reviewer personas                       |
| `claude-rescue`    | "ask claude to rescue / take over"            | Hands current Codex task + transcript context to Claude to continue      |

`claude-adversarial-review` is **not** a separate skill — `claude-review`
takes flags that select reviewer personas:

- `--experts [list]` — fan out to multiple expert personas (e.g.
  `--experts security,perf,api-design`), collect their reviews, then have
  Claude synthesize a consensus. Each persona is an
  `--append-system-prompt-file` injected for that pass.
- `--evil` (alias `--adversarial`) — runs an adversarial "evil agent"
  reviewer that actively tries to find ways the change breaks. Composable
  with `--experts` (adds an evil agent to the panel).
- Default (no persona flags) — single second-opinion reviewer.

`claude-plan` / `claude-implement` / `claude-execute` differ in autonomy
and write-permission:

- `claude-plan` — `--max-turns 10`, read-only system prompt, returns plan as
  markdown in `result`.
- `claude-implement` — `--dangerously-skip-permissions`, no shell loop,
  spec-to-patch. Output: either applied changes (`--apply`) or a
  `.handoff/claude.patch` file (default — safer).
- `claude-execute` — full agent loop, higher `--max-turns`, allows shell
  commands. Use for "do this whole task" delegations.

Build order: `claude-setup` → `claude-plan` (smallest, read-only) →
`claude-review` (default → `--evil` → `--experts` + synthesis) →
`claude-implement` → `claude-execute` → `claude-rescue`.

### Common skill contract

Each `SKILL.md` is frontmatter + prose. All six share:

1. Capture context — `git diff --no-color HEAD` (or `$BASE...HEAD` if
   `--base` passed); for rescue, serialize task + recent transcript.
2. Write handoff to `.handoff/diff.patch` (or `.handoff/task.md`).
3. Build prompt from handoff + trailing focus text.
4. Invoke:
   ```
   claude -p --bare --output-format json \
     --append-system-prompt-file <persona-or-system-prompt>.md \
     --dangerously-skip-permissions \
     --max-turns 20
   ```
   Pipe prompt via stdin, never as arg (Windows quoting).
5. Parse JSON, surface `result`. `--background` stashes session id at
   `.handoff/claude-session.txt` for later `claude --resume <id>`.

Shared flags: `--base <ref>`, `--wait`, `--background`, trailing focus text.
`claude-review` additionally takes `--experts [list]` and `--evil`.
Reviewer personas live as `personas/<name>.md` files inside the plugin and
are injected via `--append-system-prompt-file`.

### Transport: CLI primary, MCP optional

**Primary path** for every skill is the Claude Code CLI (`claude -p ...`)
shelled out from the skill body. Direct, efficient, full control over flags
(`--max-turns`, `--append-system-prompt-file`,
`--dangerously-skip-permissions`, JSON output). All six skills use this.

`.mcp.json` (registering `claude mcp serve` as an MCP server for Codex) is
shipped as an **optional** v0.1 extra — not the default surface:

- MCP is per-tool round-trips; CLI is a single agentic invocation that
  returns one JSON result. CLI is faster and uses fewer tokens.
- MCP is only useful when Codex wants fine-grained per-tool access (rare).
- Users who want it flip it on in their Codex MCP config; plugin ships the
  JSON snippet but doesn't require it.

README documents this: "use CLI skills (default); enable MCP only if you
need per-tool access".

### Distribution

No public Codex plugin directory yet. Distribute via GitHub —
`/plugin marketplace add <user>/cc-plugin-codex`. README walks through it.

## Critical files (to be created)

```
cc-plugin-codex/
├── .codex-plugin/plugin.json         # manifest — name, skills dir, mcp, interface
├── skills/
│   ├── claude-setup/SKILL.md
│   ├── claude-plan/SKILL.md
│   ├── claude-implement/SKILL.md
│   ├── claude-execute/SKILL.md
│   ├── claude-review/SKILL.md         # default + --experts + --evil
│   └── claude-rescue/SKILL.md
├── personas/                          # reviewer system prompts
│   ├── default.md
│   ├── evil.md
│   ├── security.md
│   ├── perf.md
│   └── api-design.md
├── system-prompts/                    # appended for plan/implement/execute
│   ├── planner.md
│   ├── implementer.md
│   └── executor.md
├── .mcp.json                          # optional — `claude mcp serve` snippet
├── scripts/Test-Plugin.ps1            # smoke test
├── README.md                          # install + usage (CLI default, MCP opt-in)
└── PLAN.md                            # this file
```

Manifest fields (`.codex-plugin/plugin.json`):
- `name: "cc-plugin-codex"`, `version`, `description`, `author`, `license`
- `skills: "./skills/"`
- `mcpServers: "./.mcp.json"`
- `interface.displayName`, `shortDescription`,
  `category: "Productivity"`, `capabilities: ["Read", "Write"]`,
  `defaultPrompt` examples

## Out of scope (v0.1)

- Hooks (`hooks/hooks.json` review-gate) — defer to v0.2.
- Streaming `claude -p` output back into Codex transcript (one-shot JSON only).
- Multi-turn delegated sessions managed from Codex.
- Cost/usage reporting.
- Web/IDE plugin parity (Codex CLI only).

## Risks / watch-outs

1. **Skill triggers are non-deterministic** — Codex decides when to fire
   based on the skill `description`. CI/scripted use should call
   `claude -p` directly.
2. **Auth is per-machine** — plugin assumes `claude` on PATH + already
   authenticated. `claude-setup` checks and offers
   `npm i -g @anthropic-ai/claude-code` (or PS installer on Windows).
3. **No background job manager on Claude side** — `--background` is "stash
   session id, resume later"; functional but uglier than Codex's.
4. **Windows quoting** — pipe prompts via `Get-Content -Raw`; construct
   PS-compatible commands when `$env:OS -eq 'Windows_NT'`.
5. **Trademark** — `cc-plugin-codex` uses "cc" not "claude", which sidesteps
   most of the concern; skill names still say `claude-*` and may need a
   sanity check before public release.

## Open questions (resolve at implementation)

- `claude-rescue` semantics: auto-commit Claude's changes, or always return
  a patch for the user to apply?
- Default `--max-turns` per skill (20 for single review; experts/synthesis
  likely needs higher; rescue probably higher still).
- Whether the review-gate hook lands in v0.1 or v0.2.
- Persona list for v0.1 — locked at `default`, `evil`, `security`, `perf`,
  `api-design`, or trim/extend?
- `--experts` synthesis pass: same Claude session sees all expert outputs,
  or a fresh session that only sees the aggregated text?

## Verification (when implementation lands)

1. **Static**: `cat .codex-plugin/plugin.json | jq .` parses; every
   `SKILL.md` has valid frontmatter (`name`, `description`).
2. **GitHub install loop** (no local marketplace needed):
   ```
   codex
   /plugin marketplace add <gh-user>/cc-plugin-codex
   /plugin install cc-plugin-codex@<gh-user>
   /reload-plugins
   /claude-setup            # expect: doctor runs, prints version
   /claude-plan "add a CLI flag to skip cache"
   /claude-implement "add --no-cache flag, default false"
   /claude-execute "add --no-cache flag and a test that covers it"
   /claude-review --base HEAD~1
   /claude-review --evil --base HEAD~1
   /claude-review --experts security,perf --base HEAD~1
   ```
   For pre-push iteration on a feature branch, the same flow works after
   pushing — Codex pulls the marketplace from the repo's default branch, so
   testing skill changes means push-then-`/reload-plugins`.
3. **End-to-end smoke** (`scripts/Test-Plugin.ps1`):
   - Fixture repo with a small known task.
   - `claude-plan "..."` → JSON parses, `result` contains a plan.
   - `claude-implement "..."` → `.handoff/claude.patch` exists and applies
     cleanly with `git apply --check`.
   - `claude-execute "..."` → files changed, tests pass.
   - `claude-review --base HEAD~1` → JSON parses, `result` non-empty.
   - Repeat with `--evil` and with `--experts security,perf`.
   - `claude-rescue` → resumes from stashed transcript.
4. **MCP fallback (optional)**: from a Codex session with `.mcp.json`
   loaded into the user's MCP config, invoke a Claude MCP tool (e.g.
   `Read`) and confirm it returns file contents. Skipped by default.
5. **Manual sanity**: a real review on a real PR diff — does Claude's
   `result` actually read like a useful review, not a stub?

## Next steps

1. Scaffold directories + manifest skeleton + six `SKILL.md` frontmatters +
   persona and system-prompt files.
2. Implement `claude-setup`.
3. Implement `claude-plan` (smallest, read-only) — exercises the shared
   CLI shell-out helper that the rest will reuse.
4. Implement `claude-review` in three passes: default → `--evil` →
   `--experts` + synthesis.
5. Implement `claude-implement` (patch output by default, `--apply` opt-in).
6. Implement `claude-execute` (full agent loop).
7. Implement `claude-rescue`.
8. Add `.mcp.json` (opt-in snippet) and `Test-Plugin.ps1`.
9. README (GitHub install front and center, CLI default, MCP marked
   optional) + first tagged release.
