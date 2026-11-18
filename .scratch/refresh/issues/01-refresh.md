Ceremony: full (the operator, "yes", 18 Nov 2026 01:38, RF-Q13)

# 01: /refresh <seat>…|all|lead, and the session ledger

**Status:** done (live checks last run on 1b61783, 18 Nov 2026 19:05–19:11; review loop stopped on drift, DRIFT-Q1; awaiting the lead's merge)

Decisions, with the operator's words: [../perimeter.md](../perimeter.md) (RF-Q1 to RF-Q12). Terms: [GLOSSARY.md](../../../GLOSSARY.md).

## What

- `tools/team.sh`:
  - `refresh <seat>…|all "<words>" "<pane> <time>"`: step 0 in the foreground (each name known, no refresh of it running), a `refresh-requested` ledger line, then one background run per seat started with `tmux run-shell -b`; returns at once. `lead` names the lead pane (`@role=lead`); `all` is every seat in `tools/agents`.
  - `_refresh` (the background run): defer, ask for the handoff, check it, write the task file, rewrite the registry, `respawn-pane -k`, wait for pi's input box, report to the lead.
  - `spawn` passes `--name "<seat> <YYYY-MM-DD hh:mm>"`.
  - `publish_qids` also sets the tmux option `@team-ledger` to the ledger's path (`tools/ledger`, `TEAM_LEDGER` overrides).
  - selftest cases for the above, stub pi for spawn/refresh mechanics, a real pi pane for the reads.
- `tools/extensions/ledger.ts`: on pi's `session_start` and `session_shutdown` (reason not `reload`), append `start` / `stop` to the path in `@team-ledger`, seat = the tmux window name; set the pane options `@session-id` and `@session-name` (read by `team.sh refresh` for its own ledger lines, the lead having no registry line). Writes nothing outside a team tmux server.
- `tools/extensions/refresh.ts`: `/refresh <names>` typed in the lead's pane runs `team.sh refresh <names> "<typed line>" "lead pane hh:mm"` (path from `@team-sh`) and shows its output; the lead's agent starts no turn. Elsewhere, refused with the usage.
- `tools/prompts/refresh.md`: a prompt template so `/refresh` autocompletes, as for `/draft` (the operator, "Yes, we will the same for /refresh", agentic-workflow's pane, 18 Nov 07:56, relayed by the lead 07:58): a description, an argument hint, and a body that only says to `/reload` when refresh.ts is not loaded.
- `tools/handoff.md`: the handoff template (sections of the 17 Nov handoffs; open questions in full, rule 6's form; a lead section).
- `tools/extensions/install.mjs` installs the two extensions (main session only); `.gitignore` gains `tools/ledger`; README, `docs/index.md` and `CHANGELOG.md` gain a few lines.

## Acceptance criteria

1. `/refresh x` in the lead's pane returns within a second; the lead's agent starts no turn; the pane says the refresh started; `/refresh` in another pane is refused there.
2. A seat that is busy, whose input box holds text, or with a message queued is not asked for a handoff until none holds; the ledger has one `refresh-deferred <reason>` per reason change.
3. An idle seat gets one message asking for the handoff at the named path; on a valid handoff, the pane runs a new pi with a new session id and the name `<seat> <YYYY-MM-DD hh:mm>`, whose first message is the protocol header and the new task file; the registry line names the new task file and session id; the ledger shows `refresh-requested`, `handoff-written`, the old session's `stop` and the new one's `start`, each with seat, session id and session name.
4. `REFRESH-UNADVISABLE: <reason>` as the handoff leaves the old session running and logs and reports `refresh-unadvisable <reason>`.
5. `/refresh a b` and `/refresh all` run each seat independently: one seat deferred does not delay another.
6. `/refresh lead` refreshes the lead pane: new pi with `TEAM_ROLE=lead`, a shell left when it exits, the pane keeps `@role=lead`, first message per perimeter decision 10.
7. A second `/refresh x` while one runs is refused, naming when the first started.
8. Every read (busy, input box, queue, handoff file, pane after respawn) gives yes, no or failed; a failed read never counts as idle.
9. Each outcome sends exactly one `team.sh report` to the lead.
10. pi sessions started or stopped by hand (`/new`, quit) in a team pane get `start` / `stop` ledger lines; `/reload` gets none.

## Failure modes

| Step | Failure | What it leaves | What the operator is told |
|---|---|---|---|
| 0 | unknown seat, or no window | nothing started; no ledger line | refused at once in the lead's pane, naming the seat |
| 0 | a refresh of that seat already running | the running one | refused at once: running since hh:mm |
| 0 | the registry or tmux's pane list cannot be read | nothing started; no ledger line | refused at once: cannot read <what> |
| 0 | the background run cannot be started | lock removed; `refresh-requested` logged | refused at once with tmux's error; `refresh-failed start` in the ledger |
| 1 | still deferred after `TEAM_WAIT` | old session | report `refresh-failed still deferred: <reason>` |
| 1 | the pane cannot be read as a pi pane | old session | report `refresh-unadvisable pane unreadable` |
| 2 | the handoff directory cannot be created or read | old session | report `refresh-failed cannot create/read <dir>` |
| 2 | no handoff file, or the pane never idle again, within `TEAM_WAIT` | old session; the request in the spool | report `refresh-failed no handoff at <path>` |
| 2 | the seat answers unadvisable | old session | report `refresh-unadvisable <reason>` |
| 3 | handoff empty or first line wrong | old session; the file left | report `refresh-failed bad handoff <path>: <first line>` |
| 4 | no session id from `uuidgen`, or the task file not written | old session | report `refresh-failed uuidgen gave no session id` or `task file: <error>` |
| 5 | registry not rewritten | old session | report `refresh-failed registry: <error>` |
| 6 | the seat's pane or directory cannot be read | old session; the registry names the new one | report `refresh-failed respawn: <what> cannot be read`, `team.sh revive <seat>` |
| 6 | `respawn-pane` fails | the registry names the new session | report `refresh-failed respawn: <error>`, both ids, `team.sh revive <seat>` |
| 7 | no pi input box within 60 s | old pi stopped, its session saved | report `refresh-failed no pi in pane`, the pane's last lines, both ids |
| any | a ledger append fails | the refresh carries on | the report says `ledger write failed: <error>` |
| any | the run stops unexpectedly (a failed command under `set -e`) | the old session, unless at step 6 or 7 | ledger and report `refresh-failed step <n>: stopped unexpectedly (exit <code>)` |
| any | the report cannot be queued | the outcome in the ledger | a `NOT QUEUED` line with the report in `tools/spool/log` |
| ext | `ledger.ts` cannot append | pi runs on | a pi notification in that pane |

## Checks changed

The selftest checks strengthened in review round 1 (findings 5 and 8: `reported_once`, `all_requested`, the unadvisable checks' order, the setup waits as checks, `box-pi` setting `@session-id`, the EXIT-trap checks), each first shown failing on broken code: accepted (CHK-Q1, the operator, "yes", 18 Nov 2026 19:01).

## Live check

On `tmux -L teamtest`, with its own spool, registry, ledger and handoff directory, never the team's panes: real pi panes as a seat and a lead (a real model writing a real handoff), each criterion above, and the failure rows that can be caused on purpose (unknown seat, a running refresh, deferral timeout with a short `TEAM_WAIT`, unadvisable, bad handoff, unreadable pane).
