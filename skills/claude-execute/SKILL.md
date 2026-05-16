---
name: claude-execute
description: Hand a whole task to Claude Code with full agent autonomy — plan, implement, run tests, verify, iterate. Use when you want "do X end-to-end" not just "produce a patch". Trigger on "ask claude to do X", "/claude:execute". Pass the task as trailing text.
---

# claude-execute

Full agent-loop delegation. Claude plans, edits files, runs commands (test
suites, linters, build), reads results, and iterates until done. Higher
blast radius than `claude-implement` — only use when the user explicitly
wants Claude to drive the whole task.

## Inputs

- **Trailing text** (required) — the task.
- `--max-turns <n>` (default 60).
- `--background` — fire-and-forget: stash the session id and return
  immediately; user can `claude --resume <id>` to inspect progress.
- `--no-network` — pass through so Claude can't reach the network.

## Procedure

1. **Verify** `claude` is on PATH; if not, suggest `/claude:setup`.

2. **Snapshot the base.** Record `git rev-parse HEAD` to
   `.handoff/execute-base.txt`. Warn the user if the working tree is
   dirty — execute mode will mix Claude's changes with theirs.

3. **Build the prompt.** `.handoff/task.md`:
   - The trailing task text.
   - `CLAUDE.md` (if present).
   - A reminder: "Verify your work — run the project's test suite or build
     before declaring done. If verification fails, fix and re-verify."

4. **Invoke Claude.**

   Foreground:
   ```
   claude -p --output-format json \
     --append-system-prompt-file <plugin-root>/system-prompts/executor.md \
     --dangerously-skip-permissions \
     --max-turns 60 \
     < .handoff/task.md
   ```

   Background (`--background`):
   ```
   claude -p --output-format json --print-session-id \
     --append-system-prompt-file <plugin-root>/system-prompts/executor.md \
     --dangerously-skip-permissions \
     --max-turns 60 \
     < .handoff/task.md \
     > .handoff/execute.json &
   ```
   Stash the printed session id at `.handoff/claude-session.txt` and return.

5. **Surface to the user.**
   - Foreground: print `result`, then `git status -s` and
     `git diff --stat $(cat .handoff/execute-base.txt)` so they can see
     what changed.
   - Background: print the session id and the path to `.handoff/execute.json`.

## Notes

- Executor system prompt explicitly asks Claude to verify (run tests/build)
  before claiming completion. See `system-prompts/executor.md`.
- Do **not** auto-commit. The user always reviews the final tree.
- If `--background` is used, document for the user how to resume:
  `claude --resume $(cat .handoff/claude-session.txt)`.
- This is the most expensive skill in the plugin — token-wise and
  blast-radius-wise. Confirm with the user before running on
  large/sensitive repos.
