---
name: claude-plan
description: Get an implementation plan from Claude Code for a task you describe. Read-only — Claude does not write files. Trigger on "ask claude to plan", "/claude:plan", or when a second-opinion plan is wanted before implementing. Pass the task as trailing text.
---

# claude-plan

Hand a task description to Claude Code and return its implementation plan
as markdown. No files are written by Claude — this is a planning-only call.

## Inputs

- **Trailing text** (required) — the task or question to plan.
- `--base <ref>` (optional) — include `git diff <ref>...HEAD` as context so
  Claude can plan changes layered on top of pending work.
- `--max-turns <n>` (default 10).

## Procedure

1. **Verify** `claude` is on PATH. If not, suggest running `/claude:setup`
   and stop.

2. **Build the prompt.** Concatenate, in this order:
   - The trailing task text.
   - If `--base` provided: a fenced ` ```diff ` block with
     `git diff --no-color <base>...HEAD`.
   - The contents of the repo's `CLAUDE.md` (if any, top of repo) for
     project conventions.

3. **Write the handoff** to `.handoff/task.md` (create `.handoff/` if it
   doesn't exist; it should already be in `.gitignore` of consumers but the
   plugin should not modify the consumer's `.gitignore`).

4. **Invoke Claude in plan-only mode.** Pipe the prompt via stdin:
   ```
   claude -p --output-format json \
     --append-system-prompt-file <plugin-root>/system-prompts/planner.md \
     --max-turns 10 \
     < .handoff/task.md
   ```
   Do not pass `--dangerously-skip-permissions` — planning should not touch
   files. Do not pass the prompt as an argv string (Windows quoting).

5. **Parse and surface.** Read the JSON; print `result` verbatim to the
   user. If `is_error` is true or the call exits non-zero, surface the raw
   output and stop.

## Notes

- Save the session id from the JSON (`session_id`) to
  `.handoff/claude-session.txt` so the user can `claude --resume <id>` if
  they want to iterate.
- This skill is the canonical "smallest" invocation — other claude-* skills
  reuse the same shape with different system prompts and flags.
