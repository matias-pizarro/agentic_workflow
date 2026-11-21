# Backlog

| Date | Item | Impact | Source | The operator's words |
|---|---|---|---|---|
| 21 Nov 2026 | `tools/board.mjs`: an arrow key whose escape sequence is split across two reads is taken as Esc plus two characters (Esc clears a filter being typed); fix by buffering partial sequences, a 50 ms timeout telling a lone Esc apart | low: terminals and tmux send an arrow in one write; only a very slow link splits it | team-board iteration 2 review, round 1 (TB-Q35) | "yes", team-board pane 21 Nov 2026 16:31 |
