# /refresh: perimeter

Settled with the operator in the `aw-refresh` pane, 18 Nov 2026, RF-Q1 to RF-Q12. Terms as in [GLOSSARY.md](../../GLOSSARY.md).

## Request

The operator, 18 Nov 2026 00:14: a slash command `/refresh <seat name>` that logs a handoff request, evaluates whether the seat is idle or the refresh must be deferred or is unadvisable, walks the seat through writing a handoff, stops the current agent, starts a new one in the same tmux pane, makes it the seat and has it pick up the handed-off work; every stop and start logged with the session id, seat name and session name. It runs in parallel with other work, neither blocking nor blocked.

## Decisions

1. **Where it is typed** (RF-Q1, "(a) `/refresh <name>` or `/refresh <name1> <name2> <name3>` or `/refresh all`", 00:48). In the lead's pane only, by the operator or by the lead (as `team.sh refresh`). `all` is every seat in `tools/agents`, not the lead; each seat named gets its own run.
2. **Stop and start** (RF-Q2, "yes", 01:05). The pi process stops and a new one starts in the same pane with `tmux respawn-pane -k`, not an in-process session switch.
3. **Ledger** (RF-Q5, "yes", 01:11; after "no I want us to keep a ledger of when a session starts and stops, with what seat, session-id and name, when a refresh is requested", 01:09). One shared, git-ignored file `tools/ledger` beside `tools/agents`; one line per event: `<YYYY-MM-DD hh:mm:ss TZ><TAB><event><TAB><seat><TAB><session id><TAB><session name><TAB><detail>`. A pi extension, `ledger.ts`, writes `start` and `stop` from pi's `session_start` and `session_shutdown` in every pane of the team's tmux server (seat: the window name; path: a tmux option set by `team.sh`). `team.sh refresh` writes `refresh-requested`, `refresh-deferred`, `refresh-unadvisable`, `handoff-written`, `refresh-failed`. (RF-Q3 and RF-Q4 withdrawn, overtaken by this.)
4. **Idle, deferred, unadvisable** (RF-Q6, "yes", 01:21). Deferred while the pane is busy, its input box holds text, or a message is queued for it; rechecked every `TEAM_POLL` s, logged when the reason appears or changes, `refresh-failed` after `TEAM_WAIT`. Idle when none holds. Unadvisable when the seat answers so, with its reason, or the pane cannot be read as a pi pane. Each read says yes, no or failed; a failed read is never taken as idle. STATUS `state` and `open` are not used.
5. **Handoff** (RF-Q7, "yes", 01:24). Once idle, the run queues one message asking for the handoff at `<wiki>/sources/cos-archive/handoff-<YYYY-MM-DD-hhmm>-<seat>.md` following `tools/prompts/handoff.md` (new; sections from the 17 Nov handoffs, open questions in full), or `REFRESH-UNADVISABLE: <reason>` as the file's only line. Checked once the file exists and the pane is idle again: non-empty, first line `# Handoff: seat <seat>, <date> <hh:mm>`. The run does not commit; the lead does.
6. **Session name** (RF-Q8, "yes", 01:26). `<seat> <YYYY-MM-DD hh:mm>`, set with `pi --name` by `refresh` and by `spawn`; `revive` keeps the saved name.
7. **Pickup** (RF-Q9, "yes", 01:28). The run writes `<wiki>/sources/cos-archive/task-<seat>-refresh-<stamp>.md`, first line `Ceremony: none (the user, "<typed line>", <date> hh:mm)`, pointing at the handoff and `rules.md` and asking the new session to re-ask the handoff's open questions under their IDs and report. It rewrites the seat's registry line (new task file, new session id), then `respawn-pane -k` runs `pi --session-id <new> --name "<seat> <stamp>"` with spawn's first message. `team.sh refresh <seat>… "<words>" "<pane> <time>"` takes the operator's words as `go` does; the extension fills them from the typed line.
8. **Failures** (RF-Q10, "yes", 01:31). The old session is untouched until the restart; each outcome ends with one `team.sh report`:

   | Step | Failure | Leaves | Told |
   |---|---|---|---|
   | 0 | unknown seat or no window | nothing started, no ledger line | refused at once in the lead's pane |
   | 0 | a refresh of that seat already running (per-seat lock) | the running one | refused at once |
   | 1 | still deferred after `TEAM_WAIT` | old session | `refresh-failed still deferred: <reason>` |
   | 2 | no handoff file within `TEAM_WAIT` | old session; message in the spool | `refresh-failed no handoff at <path>` |
   | 2 | seat answers unadvisable | old session | `refresh-unadvisable <reason>` |
   | 3 | handoff empty or first line wrong | old session; file left | `refresh-failed bad handoff <path>: <first line>` |
   | 4 | task file not written | old session | `refresh-failed task file: <error>` |
   | 5 | registry not rewritten | old session | `refresh-failed registry: <error>` |
   | 6 | `respawn-pane` fails | registry names the new session | `refresh-failed respawn: <error>`, both ids, `team.sh revive <seat>` |
   | 7 | no pi input box within 60 s | old pi stopped, session saved | `refresh-failed no pi in pane`, last pane lines, both ids |
   | any | ledger append fails | refresh carries on | report says `ledger write failed: <error>` |

9. **Running in parallel** (RF-Q11, "yes, except refreshing the lead itself", 01:33). A new extension `refresh.ts` handles `/refresh` in the lead's pane: `team.sh refresh` checks step 0, starts one run per seat with `tmux run-shell -b` (outside pi's process tree) and returns; the lead's agent starts no turn. Typed in any other pane, `/refresh` is refused there with its usage.
10. **The lead** (RF-Q12, "yes", 01:34). `/refresh lead` names the lead (`@role=lead`); `all` excludes it. Same deferral and handoff (`handoff-<stamp>-lead.md`, with a lead section: messages and gos in flight, what each seat waits on). Restart: `bash -ic 'TEAM_ROLE=lead pi --session-id <new> --name "lead <stamp>" "<prompt>"; exec bash'` in the lead's cwd; the pane keeps `@role=lead`. First message: chief-of-staff role, the handoff, `wiki/index.md`, `rules.md`, then `team.sh status`.

## Out of scope

Refresh on a trigger (context size, schedule); a force flag past unadvisable; automatic rollback to the old session (its id is in the ledger and the report; `pi --session <id>` reopens it); committing the handoff and task files (the lead's job); renaming sessions of seats already running.
