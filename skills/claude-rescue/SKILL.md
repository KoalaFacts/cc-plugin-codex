---
name: claude-rescue
description: Hand the current Codex task to Claude Code when Codex is stuck, looping, or out of its depth. Serializes the task description and recent transcript, lets Claude continue from there. Trigger on "ask claude to rescue", "claude take over", or when the user signals frustration with Codex's progress.
---

# claude-rescue

When Codex is stuck on a task, hand the context to Claude Code and let
Claude continue. This is the "different model, different perspective"
escape hatch.

## Inputs

- **Trailing text** (optional) — extra context or a steer for Claude
  ("you're stuck on X — try Y instead").
- `--apply` — let Claude write files directly. Default is patch mode
  (same semantics as `claude-implement`).
- `--max-turns <n>` (default 60).

## Procedure

1. **Verify** `claude` is on PATH; if not, suggest `/claude:setup`.

2. **Serialize Codex's context.** Build `.handoff/rescue.md`:
   - Section `## Original task` — the user's original request, as best
     reconstructed from the conversation.
   - Section `## What Codex tried` — a concise summary of the approaches
     Codex attempted, what worked, what didn't, what's currently broken.
     Be honest about where Codex got stuck.
   - Section `## Current state` — output of `git status -s` and
     `git diff --stat HEAD` so Claude sees the tree.
   - Section `## User's steer` (if trailing text was passed).
   - Section `## Diff so far` — `git diff --no-color HEAD` if non-empty.

3. **Snapshot the base** to `.handoff/rescue-base.txt`
   (`git rev-parse HEAD`).

4. **Invoke Claude.**

   Patch mode (default):
   ```
   claude -p --output-format json \
     --append-system-prompt-file <plugin-root>/system-prompts/executor.md \
     --dangerously-skip-permissions \
     --max-turns 60 \
     < .handoff/rescue.md
   ```
   After return, capture and roll back (same as `claude-implement`):
   ```
   git diff --no-color $(cat .handoff/rescue-base.txt) > .handoff/claude.patch
   git restore --source=$(cat .handoff/rescue-base.txt) --staged --worktree -- .
   git apply --check .handoff/claude.patch
   ```

   Apply mode (`--apply`): skip the restore step.

5. **Surface to the user.**
   - Print Claude's `result` — this includes its diagnosis of where Codex
     went wrong and what it did differently.
   - Patch mode: point to `.handoff/claude.patch` and show the stat.
   - Apply mode: show `git status -s`.
   - Stash the session id at `.handoff/claude-session.txt`.

## Notes

- The executor system prompt is reused for rescue — same full-autonomy
  loop, just with a different framing in the prompt body ("Codex tried,
  failed, here's where it got").
- Step 2 (serializing Codex's transcript) is the hardest part — Codex's
  summary of its own failure mode is what makes the handoff useful. Be
  specific: file paths, error messages, what was tried.
- Do not auto-commit. Rescue is high-blast-radius; the user reviews.
