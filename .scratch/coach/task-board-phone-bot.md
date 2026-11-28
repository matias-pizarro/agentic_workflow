Ceremony: script (the operator, "CS-Q117: Yes", 28 Nov 2026 09:50)

# Task: the phone bot's pane below the board, for good

Seat: coach. Branch: `feat/board-phone-bot` in agentic_workflow, worktree `/agents/sessions/freebsd/sandbox/worktrees/aw/feat/board-phone-bot`, from `integration` 6d0026a (v2.23.0). Relayed by the lead, 28 Nov 09:50 (CS-Q117 (a)). The operator's words, coach pane, 28 Nov 09:45: "make the phone-bot pane live in window 0, as a bottom horizontal pane that is 4 rows high and spans horizontally the 2 existing panes"; 09:46: "this should become a permanent setting". Done by hand at 09:46 (pane %9).

## What it changes

- `tools/board.mjs open`, which `team.sh revive --all` runs: after opening the board, or finding it open, it joins the pane with `@role=phone-bot` into window 0, below the board, 4 rows, full width, unless it is there already; with no such pane, it says so and moves nothing.
- postmaster's part (src, through the lead): the bot's start sets `@role=phone-bot` on its pane.
- Held unmerged while the unattended window is open (the lead, 09:50).

## Checks

- Live: `.scratch/coach/board-bot-live.sh` on a throwaway tmux server: open, open again, revive --all after the board is closed, no bot pane; integration's board.mjs leaves the bot in its own window. The real team: `board.mjs open` says already open and moves nothing.
- **If it fails:** the bot's pane stays where it starts; the lead joins it by hand after a restart.
- Review: one `code-review` pass.
