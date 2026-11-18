# 1b. /refresh code review response (code round 1)

Response to [the review](review-codex-202611180738-f49e4ed-findings.md) of f49e4ed. Each entry: what was decided, the operator's words and time, where it landed.

## 1. A refresh can stop the old session while its input box holds text

Right: step 2 broke on `idle | typing`. Fix (RF-Q17, the operator, "yes", 18 Nov 07:50): step 2 waits for `idle` only, so a seat whose input box holds text is never restarted; while it holds text, the run waits up to `TEAM_WAIT`. Landed in `tools/team.sh` (`refresh_run`, step 2). Class swept: step 1 already defers on `typing`; step 7's read is finding 5.

## 2. The registry and refresh locks do not protect concurrent seat changes

Partly right. The registry part is right: `spawn` appended and `retire` rewrote `tools/agents` without the lock refresh takes, so a spawn between refresh's read and `mv` was lost. The multi-seat refusal part is wrong: the foreground takes every lock before it starts any run, so it releases only its own. The stale-lock takeover race is real and narrow. Fix and backlog (RF-Q18, the operator, "yes", 18 Nov 07:53): a `registry_lock` helper, taken by `spawn`, `retire` and refresh's step 5; the stale-lock race, shared with `lock()`, is in [the backlog](../../backlog.md). Landed in `tools/team.sh`. Class swept: `revive` and `status` only read the registry.

## 3. Failed state reads are treated as absence or substituted state

Right. Fix (RF-Q19, the operator, "yes", 18 Nov 07:57): step 0 refuses with "cannot read" for an unreadable registry or tmux pane list; `seat_pane` fails (status 2) on a failed pane read, and the run treats it as unreadable (unadvisable, old session untouched); `session_of` writes `(unreadable)` instead of substituting, the registry's id standing in only for an unset option; `queued_for` answers `no` only when the nearest directory above the queue can be searched; step 2 ends with `refresh-failed cannot read <dir>` for an unreadable handoff directory. Landed in `tools/team.sh`. Class swept, two more instances fixed: step 6 took the lead pane's directory from a fallback on a failed read, and a seat's directory from `record | cut`, whose status is `cut`'s; both now end the run with `refresh-failed`, and step 6 also fails when the seat's pane cannot be found.

## 4. Several failures bypass the promised outcome report

Right. Fix (RF-Q20, the operator, "Yes", 18 Nov 12:27): the run's EXIT trap, `refresh_exit`, logs and reports any end that did not go through `refresh_end` as `refresh-failed step <n>: stopped unexpectedly (exit <code>)`; each step sets `step`; the new session id is checked non-empty; a report that cannot be queued goes to `tools/spool/log` as `NOT QUEUED`. The ticket's failure table gains rows for the handoff directory, an unexpected end, a report not queued, an empty id, and (from finding 3) unreadable registry, panes, pane or directory. A new selftest check, a run with no lock to write its pid into, shows the trap's line and report. Landed in `tools/team.sh` and `.scratch/refresh/issues/01-refresh.md`. Class swept: the foreground `refresh` ends through `die`, which prints its reason; `refresh_end` itself now queues through `refresh_report`.

## 5. The post-respawn check can report success without verifying the new pi

Right. Fix (RF-Q21, the operator, "yes", 18 Nov 12:31): step 7 reports `done` only once pi's input box shows and the pane's `@session-id`, set by ledger.ts at session start, equals the new id; otherwise `refresh-failed no pi in pane` after 60 s, the report asking whether ledger.ts is installed. The selftest's `box-pi` sets `@session-id` as ledger.ts does (a fixture change: CHK question with finding 8). Landed in `tools/team.sh`. Class swept: steps 1 and 2 use `pane_state` for deferral and idleness, its intended use.

## 6. Ledger metadata failures are silent or recorded as valid data

Right. Fix now (RF-Q22, the operator, "yes", 18 Nov 12:33): a window name that cannot be read is written as the seat `(unreadable)` and shown in the pane; a failed set of `@session-id` or `@session-name` is shown in the pane, saying team.sh refresh will not see the start. Landed in `tools/extensions/ledger.ts`. Class swept: the ledger path read (`@team-ledger`) treats unset and unreadable alike as "not a team pane" and writes nothing, the behaviour the perimeter asks outside a team server; refresh.ts's `@role` and `@team-sh` reads already refuse with their reason.

## 7. Step 0 hides tmux's start error

Right. Fix now (RF-Q23, the operator, "yes", 18 Nov 18:27): `tmux run-shell`'s own error is printed in the refusal and written in the `refresh-failed start: <error>` ledger line. Landed in `tools/team.sh`. Class swept: step 5's registry rewrite also dropped awk's and mv's errors; it now carries them. The deliverer's start in `enqueue`, outside this ticket, already prints its reason.

## 8. Several selftest assertions can pass on stale evidence or timing

Right, except the lifecycle point: pi's session events stay with the live run (RF-Q14). Fix (RF-Q24, the operator, "yes", 18 Nov 18:30): "exactly one report" counts the queued report files and delivered lines (`reported_once`); the `all` count is a polled function (`all_requested`); the first unadvisable answer's checks run before the next refresh starts; the seven `|| true` setup waits, and two `waitfor ... &&` waits, are checks. Each changed check was first shown failing on code broken for its purpose, on copies under /tmp/aw-refresh/brk{A,B,C,D} (own tmux servers): report sent twice, `all` expanding one seat, unadvisable not logged, box-pi never busy. The first run of A passed "exactly one": `enqueue` writes no final newline, so `cat` joined the two reports into one line; fixed to count files, then A failed as it should (st-brkA2.log). Real selftest 110 ok (st14.log). Class swept: seven answer writes that aborted the selftest under `set -e` on an empty path after an earlier failure now go through `answer` or a guard, so the run reaches its summary. A CHK question goes to the operator for these checks and the box-pi `@session-id` fixture (finding 5).

## 9. Delete the unused `refreshes` selftest helper

Right. Deleted (RF-Q25, the operator, "yes", 18 Nov 18:31). Class swept: every other helper in the refresh section has a caller.

Disposition: agreed with the review on findings 1 and 3 to 9; on finding 2, agreed on the registry lock, disagreed that a multi-seat refusal removes locks handed to background runs (it releases only its own), and the stale-lock race went to the backlog.
