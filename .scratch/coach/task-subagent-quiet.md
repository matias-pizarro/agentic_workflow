Ceremony: script (the operator, "CS-Q121: Yes", 28 Nov 2026 13:20)

# Task: the pane-writing extensions do nothing in a subagent

Seat: coach. Branch: `fix/subagent-quiet` in agentic_workflow, worktree `/agents/sessions/freebsd/sandbox/worktrees/aw/fix/subagent-quiet`, from `integration` (v2.24.0). Relayed by the lead, 28 Nov 13:20 (CS-Q121 (a)), after postmaster's refresh of 13:04 named a review subagent's session as postmaster's.

## What it changes

`tools/extensions/ledger.ts`, `refresh.ts`, `beep.ts` and `open-questions.ts` register nothing when `PI_SUBAGENT_CHILD=1`: pi-subagents runs each subagent as a child process with it set (read in a live run), and the child inherits the seat's `TMUX_PANE`.

## Checks

- Live: `.scratch/coach/subagent-live.sh`: a real pi in a seat-like pane of a throwaway tmux server, with a throwaway agent dir, starts a background subagent. On integration's extensions the ledger gets the subagent's start and stop lines and the pane's `@session-id` becomes the subagent's; on the branch's, only the main session's start line, and the pane keeps the main session's id.
- **If it fails:** a subagent's session keeps writing the seat's ledger lines and pane options.
- Review: one `code-review` pass.
