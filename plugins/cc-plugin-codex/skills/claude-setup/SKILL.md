---
name: claude-setup
description: Verify the Claude Code CLI (`claude`) is installed, authenticated, and healthy. Run on first use of cc-plugin-codex or when other claude-* skills fail with "claude not found" / auth errors. Trigger on `/claude:setup`, "set up claude", or "check claude".
---

# claude-setup

Confirm the host machine can run delegated Claude Code sessions. This is a
read-only diagnostic — it never installs anything without confirmation.

## Procedure

1. **Detect the CLI.** Try `claude --version` (capture stdout + exit code).
   - On success: print the version and continue to step 2.
   - On failure: tell the user `claude` is not on `PATH`. Offer to install:
     - macOS / Linux: `npm i -g @anthropic-ai/claude-code`
     - Windows: `irm https://claude.ai/install.ps1 | iex`
     Do NOT run the installer automatically — ask first.

2. **Run the doctor.** Shell out:
   ```
   claude doctor
   ```
   Stream stdout to the user. If any check fails, surface the failing line
   verbatim and stop — do not attempt to auto-fix auth or config.

3. **Smoke-test a tiny prompt.** Pipe a one-token prompt and confirm a JSON
   reply parses:
   ```
   echo "reply with the single word: ok" | claude -p --output-format json --max-turns 1
   ```
   - Parse the JSON; if `result` contains "ok" (case-insensitive), report
     "Claude Code is healthy" plus the version from step 1.
   - On parse failure or non-zero exit, surface the raw output and exit
     non-zero.

## Notes

- Honor `CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY` if set — do not
  prompt for login when an env-var auth path is already configured.
- On Windows, run all commands through `pwsh -NoProfile -Command` if you
  need to pipe; bare `echo | claude` works in PowerShell 7+.
- Treat this skill as idempotent: running it twice in a row should be safe.
