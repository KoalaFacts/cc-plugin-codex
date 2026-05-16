---
name: claude-review
description: Get a second-opinion code review from Claude Code on the current git diff. Trigger on "ask claude to review", "/claude:review", or before merging when a fresh perspective is wanted. Supports `--evil` for an adversarial reviewer and `--experts <list>` to fan out to expert personas (security, perf, api-design) and synthesize a consensus.
---

# claude-review

Run a Claude Code review pass over the pending diff. By default a single
second-opinion reviewer; flags switch to adversarial or multi-expert mode.

## Inputs

- `--base <ref>` (default `HEAD`) — diff against `<ref>...HEAD`.
- `--evil` (alias `--adversarial`) — use the adversarial reviewer persona.
- `--experts <list>` — comma-separated expert personas (e.g.
  `security,perf,api-design`). Fans out one pass per persona, then runs a
  synthesis pass that produces consensus + per-persona summaries.
  Composable with `--evil` (adds the evil reviewer to the panel).
- Trailing text — extra focus / instructions for the reviewer(s).

Personas live at `<plugin-root>/personas/<name>.md` and are injected via
`--append-system-prompt-file`. Available: `default`, `evil`, `security`,
`perf`, `api-design`.

## Procedure

### 1. Capture the diff

```
git diff --no-color <base>...HEAD > .handoff/diff.patch
```

If the diff is empty, report "no pending changes vs <base>" and stop.

### 2. Choose mode

- **Default** (no flags): single reviewer using `personas/default.md`.
- **`--evil`** only: single reviewer using `personas/evil.md`.
- **`--experts <list>`** (with or without `--evil`): one Claude invocation
  per persona, then one synthesis invocation.

### 3. Build the prompt template

```
You are reviewing a pending change. The diff is attached below.

<focus text from trailing args, if any>

Diff:
```diff
<contents of .handoff/diff.patch>
```
```

Write this to `.handoff/review-prompt.md`.

### 4. Invoke Claude

For each persona in the chosen set:

```
claude -p --output-format json \
  --append-system-prompt-file <plugin-root>/personas/<persona>.md \
  --max-turns 20 \
  < .handoff/review-prompt.md \
  > .handoff/review-<persona>.json
```

Parse each JSON; collect the `result` strings.

### 5. Single-persona output

If only one persona ran, print its `result` verbatim under a heading like
`## Claude review (<persona>)` and stop.

### 6. Multi-persona synthesis (`--experts`)

After all per-persona reviews complete, build a synthesis prompt:

```
You will see N reviews of the same diff, each from a different reviewer
persona. Produce a consensus review:

1. Issues every reviewer flagged (highest signal).
2. Issues flagged by multiple reviewers.
3. Persona-specific findings worth keeping.
4. False positives or disagreements.

Reviews:

### <persona-1>
<result-1>

### <persona-2>
<result-2>

...
```

Write to `.handoff/synthesis-prompt.md` and invoke:

```
claude -p --output-format json \
  --append-system-prompt-file <plugin-root>/personas/default.md \
  --max-turns 10 \
  < .handoff/synthesis-prompt.md
```

Print the synthesis `result` under `## Claude review (consensus)`, then
list each per-persona review under collapsed sub-headings the user can
expand.

## Notes

- The synthesis pass uses a **fresh** Claude session that only sees the
  aggregated review text — it does not re-read the diff. This keeps the
  consensus pass focused on reconciling the panel rather than re-reviewing.
- Persist all intermediate artifacts in `.handoff/` so the user can
  re-synthesize without re-running the reviewers.
- Default `--max-turns` is 20; experts may need more if reviewers want to
  read additional files. Bump to 30 if a reviewer ran out of turns.
