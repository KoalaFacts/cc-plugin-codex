---
name: claude-implement
description: Hand a spec/task to Claude Code and get back a patch (or applied changes). No test/verify loop — pure spec-to-code. Trigger on "ask claude to implement", "/claude:implement". Defaults to writing a patch the user reviews before applying; pass `--apply` to let Claude write files directly.
---

# claude-implement

Convert a task description into code changes. Default output is a patch
file at `.handoff/claude.patch`; `--apply` lets Claude write files
directly into the working tree.

## Inputs

- **Trailing text** (required) — the task or spec.
- `--apply` — write files directly instead of producing a patch.
- `--base <ref>` — start from `<base>` instead of `HEAD` (Claude diffs
  against this).
- `--max-turns <n>` (default 30).

## Procedure

1. **Verify** `claude` is on PATH; if not, suggest `/claude:setup`.

2. **Snapshot the base.** Record `git rev-parse HEAD` into
   `.handoff/implement-base.txt` so we can produce a clean patch later.

3. **Build the prompt.** `.handoff/task.md` contains:
   - The trailing task text.
   - The repo's `CLAUDE.md` if present (project conventions).
   - A reminder: "Make the smallest change that satisfies the spec. Do not
     run tests. Do not refactor adjacent code."

4. **Invoke Claude.**

   Patch mode (default):
   ```
   claude -p --output-format json \
     --append-system-prompt-file <plugin-root>/system-prompts/implementer.md \
     --dangerously-skip-permissions \
     --max-turns 30 \
     < .handoff/task.md
   ```
   Claude will edit files in the working tree. After it returns, capture
   the patch:
   ```
   git diff --no-color $(cat .handoff/implement-base.txt) > .handoff/claude.patch
   git restore --source=$(cat .handoff/implement-base.txt) --staged --worktree -- .
   ```
   The restore step rolls the working tree back so the user can review the
   patch and choose whether to apply it. Verify the patch applies cleanly:
   ```
   git apply --check .handoff/claude.patch
   ```

   Apply mode (`--apply`): same invocation, but skip the restore step.
   Files stay modified.

5. **Surface to the user.**
   - Patch mode: print Claude's `result` (its explanation), then the path
     to `.handoff/claude.patch`, then the diff stat
     (`git apply --stat .handoff/claude.patch`).
   - Apply mode: print `result` + `git status -s` of the tree.

## Notes

- Implementer system prompt tells Claude not to run tests and not to
  expand scope. See `system-prompts/implementer.md`.
- `--max-turns 30` is conservative — bump for larger specs.
- If `git apply --check` fails (e.g. Claude touched files outside its
  worktree), surface the error and the patch path. Do not auto-apply.
- Do not commit on the user's behalf in either mode.
