# 2b. /refresh code review response (code round 2)

Response to [the review](review-codex-202611181844-7a34b30-findings.md) of 7a34b30. Every finding of this round sits in lines round 1 added or changed: drift (rules.md rule 7). DRIFT-Q1, the operator, "yes", 18 Nov 2026 19:04: stop the loop; fix finding 5 now; send findings 1 to 4, 6 and 7 to [the backlog](../../backlog.md). The loop stops on drift.

## 1. The registry lock does not serialize a seat's lifecycle

Backlog (DRIFT-Q1). Needs a retire or respawn of the seat during its refresh.

## 2. An idle screen does not establish that the handoff file is complete

Backlog (DRIFT-Q1). The run already waits for the pane to go idle after the file exists; pi shows Working for the whole turn.

## 3. Failed state reads still become absence, delay, or the wrong outcome

Backlog (DRIFT-Q1). Each instance ends in a refusal or failure, with the wrong reason.

## 4. Some failure paths leave locks or records in a misleading state

Backlog (DRIFT-Q1). Each needs a failed write.

## 5. The new EXIT cleanup does not check lock ownership

Right. Fixed (DRIFT-Q1): the run claims the lock with noclobber (`set -C`), failing when a run already holds it, and its EXIT trap removes the lock only when the pid in it is its own. Checked by hand: a `_refresh` started on a lock held by a live process is refused, logged `refresh-failed step 0: stopped unexpectedly (exit 2)`, and the holder's lock and pid stay. Landed in `tools/team.sh`. Class swept: `refresh_lock`'s takeover of a dead run's lock is the backlogged stale-lock race; the foreground releases only locks it took in the same call.

## 6. A failed ledger-path lookup can silently omit start and stop lines

Backlog (DRIFT-Q1). Needs tmux to fail at session start or stop.

## 7. Two revised selftest checks can still pass on broken behavior

Backlog (DRIFT-Q1).

Disposition: agreed that prior findings 5, 6, 7 and 9 are resolved; on 1, 2, 3, 4 and 8, the narrower cases the table names are this round's findings 1 to 7, decided above.
