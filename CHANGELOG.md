# Changelog

Every release of this repo, newest first, in the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as `README.md` defines it for this repo: a major release asks a project to act, and its entries say how.

## [2.17.0] - 2026-11-22

### Added

- Rule 16, the team's shape (the operator, 22 Nov 20:47, 20:58, 21:00; AW-Q171, AW-Q172): one seat designs, builds and maintains its component. Coordinators (the Lead, Architecture, Methodology, Docs, Security) each keep one dimension consistent and hold its single source of truth; a change touching a coordinator's dimension goes through that coordinator. Builders each design, build and maintain one area of components, named by the project. Coordinators and the builders the project names are always on; other builders roll off with their check-out and their components' READMEs current, and roll on from a task file naming both; while one is off, the Lead triages incidents on its components. index.md's roles and reason, GLOSSARY.md (Coordinator, Builder, Roll on, roll off) and kickoff.md (step 12, name the seats) follow. **Act:** every seat, from its next turn: send a change touching a coordinator's dimension through that coordinator; the lead: reshape the team on the operator's word (CS-Q79), each rename a retire with check-out and a spawn on the handoff.

## [2.16.1] - 2026-11-21

### Fixed

- `tools/board.mjs`: a seat whose window has `@working` shows as working, with no waiting-for, as its tab shows only ⚡; it showed the previous turn's state (team-board, TB-Q38, TB-Q39). **Act:** none for seats; restart a running board to take it.

## [2.16.0] - 2026-11-21

### Added

- `tools/board.mjs`, iteration 2 (team-board, TB-Q32 to TB-Q37): an action's outcome stays shown, the view scrolls to the selected row, times sort by elapsed time; split escape sequences backlogged (TB-Q35). **Act:** none for seats; restart a running board to take it.

### Changed

- `.scratch/backlog.md`, the shared backlog, is now tracked in git, with every entry (AW-Q168 (a)). **Act:** every seat: append to it as before, and commit the line on your branch with the work it comes from.

## [2.15.0] - 2026-11-21

### Added

- `tools/board.mjs`, the team board (team-board, TB-Q1 to TB-Q31): a read-only, full-screen table of the seats (name, context %, state, open, waiting-for, since creation, since refresh) and one of their Vikunja tasks, redrawn as they change; `board.mjs open` starts it in window 0 of the lead's session unless a window named `board` exists, and `team.sh revive --all` runs that as its last step (TB-Q29). **Act:** none for seats; the operator gets the board back at the next `team.sh revive --all`, or runs `node <root>/agentic_workflow/tools/board.mjs open`.

## [2.14.0] - 2026-11-21

### Added

- Rules (Team mechanics): the STATUS field `for=<PM|lead|seat-name>`, after `state=`: who the seat waits for: `for=PM` with `waiting-for-PM`, `for=lead` with `ready-for-lead`, the first seat waited for with `waiting-for-seat`; left out in the other states (AW-Q156; TB-Q2, TB-Q3). `team.sh spawn`'s prompt carries it (TB-Q19).
- `open-questions.ts` reads `for=` and publishes each seat's STATUS fields and context % to tmux, for team-board's table; `team.sh spawn` writes a spawn line to the ledger (team-board, TB-Q1 to TB-Q5, TB-Q18). A 2.13.0 extension stops reading a STATUS line carrying `for=`. **Act:** every seat: reload in the turn that receives this, with `reload_runtime`; from the next STATUS line after that, add `for=PM`, `for=lead` or `for=<seat>` after `state=` when waiting.

## [2.13.0] - 2026-11-21

### Added

- `tools/extensions/beep.ts`, `/beep-from all|<seat>` and `/mute all|<seat>`, typed in any pane: an audible signal (`beep` three times) at the end of a seat's turn that asks a new ❓ question or newly enters `waiting-for-PM`, unless that seat is muted. Everything starts muted, and is muted again after a tmux server restart; the switch is the global option `@beep-all` and a seat's window option `@beep`. Rules (Team mechanics): agents play no signal themselves (AW-Q157 to AW-Q164). **Act:** every seat: stop playing the signal by hand (the lead's 11:25 relay), and reload in the turn that receives this, with `reload_runtime`. The operator types `/beep-from all` (or `/beep-from <seat>`) to hear it.

## [2.12.2] - 2026-11-20

### Fixed

- Rules (Team mechanics): the STATUS states defined: `ready-for-lead` only when a deliverable waits for the lead's review or merge authorisation; `idle` when nobody owes the seat anything, a report sent included; `done`, `working` and `blocked` (AW-Q149). A seat had shown `ready-for-lead` for 25 minutes after a progress report. **Act:** every seat, from its next STATUS line.
- Rules (Team mechanics): a request to reload (a release that changed an extension or a prompt template, a new token, a changed setting) is taken in the turn that receives it, with the `reload_runtime` tool, which takes effect when that turn ends; no longer "once idle" (AW-Q150). A seat had reloaded 1 h 24 min after a token change. **Act:** every seat, at the next request; the lead words its requests so.

## [2.12.1] - 2026-11-20

### Fixed

- Rules (Team mechanics) and the `/open-questions` template: the lead relays, and lists in its table, only questions the operator can answer now; a question a seat has yet to ask gets no row (AW-Q147). A table had listed "your go for the record, once it asks". **Act:** the lead, from its next summary.

## [2.12.0] - 2026-11-20

### Added

- Rules (rule 4 and Team mechanics): every step a seat waits on the operator for (an answer, a go, a release, a read of a diff, a look at a render, an approval) is an open question with an ID, counted in `open` and printed by `/open-questions`, so `state=waiting-for-PM` comes with `open` above 0; when the lead holds a seat's work on such a step, it tells the seat with `team.sh send`, and the seat asks it in its own pane (AW-Q140). The lead's `/open-questions` table names question IDs only, a seat's wait without one as `no ID: <its ask>` (AW-Q141, AW-Q145). **Act:** every seat, the lead included, from its next turn: ask each present wait on the operator as a question.
- `open-questions.ts` warns in the pane when a turn's last STATUS line says `state=waiting-for-PM` with `open=0` (AW-Q140). **Act:** each seat takes it at its next `/reload` or refresh.

## [2.11.0] - 2026-11-20

### Added

- `open-questions.ts` makes md-html pages mechanical: every full path to an existing Markdown file in a reply gets its page, listed in the pane under "Pages to open in a browser" before the STATUS line (display only; the reply stays as written), and made at the end of the turn by the md-html beside team.sh; a failure is noticed in the pane; outside the team's tmux nothing happens (AW-Q135, AW-A1, AW-A2). A path containing a space gets no page (backlog). **Act:** each seat takes it at its next `/reload` or refresh; the rule to name pages stays.

## [2.10.2] - 2026-11-20

### Fixed

- Rules (Team mechanics): `state=waiting-for-PM` only when the operator can act now; while the lead or another seat must act first (a grill, a consolidation, a merge authorisation, a review), the state is `waiting-for-seat`, even when the operator's step comes after theirs (AW-Q138). Two seats had raised ✋ while waiting on the lead's grill. **Act:** every seat, from its next STATUS line.

## [2.10.1] - 2026-11-19

### Fixed

- `md-html` wrote its page beside the Markdown, which left an untracked `.html` in a repo for every tracked file it was run on. It now writes under `<root>/html/`, mirroring the Markdown's full path, outside every repo; relative links and images point at the Markdown's own folder; it refuses when that folder would be inside a git work tree (AW-Q128, AW-Q130 to AW-Q132). **Act:** every seat names the page path md-html prints; the lead removes `src/infra/vikunja/README.html`, left by 2.10.0.
- The README's tab format shows only ⚡ while a seat works, hiding ✋ and ⏳ until the turn ends; `[n]` stays (AW-Q133). **Act:** the operator updates both tab formats in their tmux config, as `README.md` shows.

## [2.10.0] - 2026-11-19

### Added

- `tools/md-html <file.md>…` writes `<file>.html` beside each Markdown file and prints its path: rendered with marked from pi's install, raw HTML shown as text and only http, https, mailto and relative links kept, so a page runs no script an agent wrote; Mermaid blocks drawn by Mermaid 12.3.0 from jsDelivr. Rules (Team mechanics) and the `/open-questions` template: every Markdown file named to the operator also goes as that HTML page, remade after the Markdown's last change, and the reply names the page (AW-Q120). **Act:** every seat, from its next turn.
- Rules (Team mechanics): a seat reads rules.md only when its session starts, so after each release with an **Act** line for seats the lead sends that line to every running seat, with a `/reload` when an extension changed (AW-Q122). **Act:** the lead, after each release, starting with this one.

### Changed

- Rule 6: each solution is lettered (a), (b), (c)…, so the operator can answer with its letter, and the `➡️` names the recommended letter (the user, 19 Nov 22:37). **Act:** every seat, from its next question.

## [2.9.0] - 2026-11-19

### Added

- A seat's tmux tab shows ⏳ after its name while its last STATUS line says `state=ready-for-lead` or `state=waiting-for-seat`, the seat waiting on the team rather than the operator: `open-questions.ts` sets the window option `@wait`, cleared by the seat's next STATUS line saying another state (AW-Q118). **Act:** the operator adds `#{?@wait, ⏳,}` to both tab formats in their tmux config, as `README.md` shows; each seat takes it at its next `/reload` or refresh.

## [2.8.0] - 2026-11-19

### Added

- Rules (Team mechanics): when relaying that a seat waits on the operator, the lead names the question's ID and the pane it is in (AW-Q114, CS-Q43). **Act:** the lead, from its next relay.
- Rules (Team mechanics) and the `/open-questions` template: nothing follows a path but a space or the end of its line, no full stop, comma, colon or bracket, which a double-click would select with it (AW-Q116). **Act:** every seat, from its next turn.

## [2.7.0] - 2026-11-19

### Added

- Rules (Team mechanics): `state=waiting-for-PM` whenever a seat's next step waits on the operator (an answer, a go, a release or a step only they can run), with or without an open question; the `ask=` says what it waits for (AW-Q112). With 2.6.0, its tab then shows ✋. **Act:** every seat follows it from its next turn.
- `team.sh status` opens with `NO DELIVERER for <target>: <n> message(s) queued …` for each queue whose deliverer is not running, with the command that starts one.

### Fixed

- `team.sh send`, `report` and `go` piped into a reader that stops early (`… | head -1`) started no deliverer when the target was busy: the second line of output killed team.sh first, and the message stayed queued until the next send to that seat. The deliverer now starts before anything is printed, and output that nobody reads no longer stops `refresh` or `revive --all` part-way (CS-Q40). **Act:** none: team.sh runs from the team's checkout, which moves to 2.7.0.

## [2.6.0] - 2026-11-19

### Added

- A seat's tmux tab shows ✋ after its name while its last STATUS line says `state=waiting-for-PM`, with or without an open question: `open-questions.ts` sets the window option `@todo`, cleared by the seat's next STATUS line saying another state or once the operator types in its pane (AW-Q99). **Act:** the operator adds `#{?@todo, ✋,}` to both tab formats in their tmux config, as `README.md` shows; each seat takes it at its next `/reload` or refresh.

## [2.5.0] - 2026-11-18

### Added

- Unattended windows: a readiness round opens the grill (`docs/unattended-windows.md`, "Opening: the grill"; rule 15). The lead names the taking-part seats and their targets; each seat writes what it needs to reach them unattended (credentials, operator-only steps, questions, shared files, relaxations, its fallback queue); the architecture seat, or the lead, reviews the lists across seats; one consolidated list for the operator opens the grill. At the start, an unmet need is not granted and that seat drops to its fallback queue.
- Unattended windows: temporary credentials. The grill may let seats make WireGuard peers, ssh keys or tokens for the window, narrowly scoped; each is a ledger line with its undo; the seat retires its own once its work is done; an end-of-window sweep retires the rest before the morning report, and one it cannot retire is the report's first incident; at close, the lead asks the operator for long-term credentials made outside the agents' environment.

### Changed

- Rule 15's floor forbids revoking or deleting a credential the window did not create (before: any credential). **Act:** the lead runs the end-of-window sweep before the morning report.

## [2.4.0] - 2026-11-18

### Added

- `team.sh retire <seat>` refuses until the seat's check-out exists at `wiki/sources/checkouts/<yyyy-mm-dd>-<seat>.md` (2.3.0's rule), naming an unreadable or empty one as such; `retire <seat> --no-checkout "<reason>"` retires a seat that crashed or never started, and logs the reason. **Act:** the lead has each seat write its check-out before retiring it, as rules.md already says.
- Rules (Team mechanics): a path is given in full, from `/`, and reachable from outside the sandbox (never `/tmp`), so one click selects it; the `/open-questions` template says the same. A Mermaid diagram meant for the operator also goes in an HTML page made from `tools/mermaid.html` (Mermaid 12.3.0 from jsDelivr).
- `docs/kickoff.md` installs the `show-me` skill (humanlayer/skills), typed as `/skill:show-me`.

### Fixed

- A refresh's report and the new session's task file show `unnamed` for an old session that has no name (one spawned before 2.3.0), not a blank.

## [2.3.0] - 2026-11-18

### Added

- A check-out before a seat retires (rules.md, Team mechanics): the seat writes `<root>/wiki/sources/checkouts/<yyyy-mm-dd>-<seat>.md` following `tools/checkout.md` (Brief, Delivered with commits, Challenges, Key events, Learnings, Follow-ups for a successor) and commits it in the wiki; then the lead retires it. A seat going on in a new session is refreshed with a handoff instead.

- `/refresh <seat>…|all|lead`, typed in the lead's pane, and `team.sh refresh`: hand a seat, or the lead, to a new pi session in the same pane through a handoff (`tools/handoff.md`), deferred while the seat is busy, typing or has a message queued, refused when the seat answers it is unadvisable; the lead's pane is free at once and gets one report per seat.
- The session ledger, `tools/ledger`: `ledger.ts` logs every pi session's start and stop with its seat, session id and session name; `team.sh refresh` logs its steps. Add `tools/ledger` to the wiki's `.gitignore` beside `tools/agents`.
- `team.sh spawn` names each session `<seat> <YYYY-MM-DD hh:mm>`.

## [2.2.1] - 2026-11-18

### Fixed

- `/draft` and the four unattended-window commands are listed in pi's autocomplete: one prompt template each in `tools/prompts/`. Their extensions still handle the typed line first; a template's own text only asks for `/reload` when its extension is not loaded. After installing, `/reload` the panes `install.mjs` lists.

### Changed

- `docs/commands.md` lists the commands, extensions and prompt templates, with where each command is typed and the file that provides it; the README lists the commands one per row and links to it.

## [2.2.0] - 2026-11-18

### Added

- Rule 15, unattended windows, and `docs/unattended-windows.md`, the lead's procedure: only the operator opens, starts, aborts or ends a window, with four commands typed in the lead's pane. The window's grill sets its terms (end, where, production changes, spend, outward steps, merges on assumptions, the queue, recovery, relaxations); what it grants is the operator's go for that window only. Whatever is granted, agents never cross the rule's fixed floor, write each change's undo before making it, report each change for the window's ledger, proceed on their own recommendation recorded as an assumption, and hold rather than improvise when a check fails.
- `tools/extensions/unattended.ts`, installed by `install.mjs` for the main session: `/unattended-window <intent>`, `/abort-unattended-window`, `/start-unattended-window` and `/end-unattended-window`, each acting only in the lead's pane and in that order (state: the pane's tmux option `@unattended`), refused elsewhere with the line put back. After installing, `/reload` the panes `install.mjs` lists. Its tests: `node tests/unattended/run.mjs`.

## [2.1.1] - 2026-11-18

### Fixed

- `install.mjs` lists, among the panes needing `/reload`, a pane whose shell runs pi, as the lead's does; before, it listed only panes whose own process is pi.

## [2.1.0] - 2026-11-18

### Added

- `/draft <description>` (`tools/extensions/draft.ts`, installed by `install.mjs` for the main session). Typed in the lead's pane (tmux pane option `@role=lead`), it becomes, stamped with the time: "Task an agent with <description>.", the request to settle the task's perimeter with the operator using `grill-with-docs` and to propose how to follow (`implement`, `to-spec` + `to-tickets`, a new task on the board, or something else altogether), and to choose the seat, its working directory, branch and worktree. Typed in another pane, it is relayed to the lead with `team.sh report` and that seat carries on; a failed relay puts the line back in the input box. After installing, `/reload` the panes `install.mjs` lists.
- `team.sh` publishes its own path as the tmux option `@team-sh`; `team.sh report` with `TEAM_QIDS_SKIP=1` relays the text without registering its `❓` IDs.

## [2.0.0] - 2026-11-17

### Changed

- **Act:** `team.sh go` takes where and when the user gave the go: `team.sh go <name> "<words>" "<pane> <time>" "<instruction>"`, e.g. `"prod-net pane 22:57"`, the stamp on the user's message. It sends `Lead: the user's go ('<words>', <pane> <time>), relayed <now>: <instruction>`, and refuses a source without a time. The old three-argument form exits with its usage.
- **Act:** after installing (`node tools/extensions/install.mjs`), `/reload` each pane it lists, or tell its seat to call the `reload_runtime` tool.
- Rule 2 and the overview: live runs are for tiers with a live check (all but `research`, `write-up` and `retro`); the overview points to the tier table.
- Rule 6, `docs/index.md`, the `/open-questions` template and `review-loop`: every impact, rating, comparison and recommendation leads with the absolute value against the threshold that matters, and gives the relative change only after.

### Added

- Ceremony tiers `research` (findings as a Markdown file and its HTML version, citing primary sources; your read as the review), `write-up` (a draft: an email, an invite, a brief, a rationale; one pass on a different model, then your read; sending waits for your go), `retro` (rule 12's shape) and `vg` (slide decks, diagrams, images, mockups; the render, PDF or PPTX shown to you; your feedback before commit). `none` stays for other no-code work. `team.sh spawn` accepts them. A project whose ticket checker or board lists the tiers (src's `lib/check_ticket`, Vikunja's `tier:` labels) should add them.
- guards.ts stamps each message typed in a pane, other than a `/command`, with its local time, `[17 Nov 12:59] `.
- sibling-guard also refuses a `bash` call beside another `bash` call when either runs a git step that changes state or `merge-ready`.
- open-questions.ts registers each new `❓ <ID>` of a turn to the seat in the question-ID registry (`team.sh` puts its path in the tmux option `@team-qids`), and warns in the pane of an ID another seat holds, or of IDs it cannot register. It gives each seat a `reload_runtime` tool, to use on the lead's or the operator's word.
- `install.mjs` ends by listing the tmux panes running pi that need `/reload`.
- `team.sh status` prints a `CRON` line when the last run in `tools/spool/cron.log` exited non-zero; the selftest also expects delivery after the sender is killed.
- `tools/wiki-pre-commit` refuses an added line whose leading `<d> <Mon> hh:mm` is later than the commit's clock.
- `merge-ready` warns of each ticket the branch changed whose `**Status:**` is not `done`.
- Rule 4: a question settled by an answer given elsewhere is withdrawn in its own pane, naming that answer; a ticket's number is claimed by committing its file before it is announced.
- Rule 5: the time quoted is the stamp on the operator's message, or the time a seat's report quotes, never an estimate; a claim about state, by anyone, names the read it rests on, made after the last step that could change it (moved from rule 10, which bound only the lead); an answer about now is recorded as a choice for now, and a standing rule changes only on the operator's words naming it.
- Rule 9: the seat merges the integration branch into its branch before each review pass too; a change to a shared file merges into the integration branch on its own, from its owner's branch, first.
- Rule 10: a go is relayed as given; a condition the lead would add goes to the operator as a question.

## [1.10.0] - 2026-11-17

### Added

- A `docs` ceremony tier (rule 1, and the tier table in `docs/index.md`): a change to documentation only, with no code, script or check. It has an `**If it fails:**` line, the project's docs build as its live check, and the operator's read of the diff or render as its review. `team.sh spawn` accepts `Ceremony: docs`. A project whose ticket checker lists the tiers (such as src's `lib/check_ticket`) should add `docs` there.

## [1.9.0] - 2026-11-17

### Added

- `team.sh doctor` has an `http <url> <status> | <fix>` kind: the URL must answer with that status within 5 s, and no answer is a FAIL.
- `team.sh status` ends a QUEUED line with `(no deliverer: ...)` when no deliverer is running for that queue.
- `/open-questions` lists each assumption recorded for the operator to confirm ("assumption: <ID>, confirm") as an open question, with the assumed answer as the ➡️. The input box prefill also takes `-A<n>` IDs, e.g. `VW-A3`.

### Fixed

- `team.sh` starts its deliverer from the tmux server, outside the caller's process tree. A `team.sh` call run under `timeout(1)` (a process reaper on FreeBSD), or by a harness that kills its process group, no longer kills the deliverer and strands queued messages. Without a reachable tmux server, the message stays queued and `send` says so.

## [1.8.0] - 2026-11-17

### Added

- A seat's tab shows its open-question count after the name, e.g. `3:prod-net [5]`. The extension sets the tmux option `@open` from the STATUS line's `open=`, and clears it at `open=0` or when the operator types in the pane. Update the two tab-format lines in your tmux config from the README's "Guards" section, then `/reload` the seats.

## [1.7.1] - 2026-11-16

### Changed

- A `worst=high` tab is dark red (colour 88) with light grey text (colour 254), like the active tab's text. Orange and yellow are unchanged. Seats pick it up at `/reload`.

## [1.7.0] - 2026-11-16

### Changed

- The STATUS line every agent ends its turn with gains `open=<n>` and, whenever `n` is above 0, `worst=<high|medium|low>`: the agent's questions to the operator still unanswered, and the highest criticality among them (`docs/rules.md`, Team mechanics; `team.sh`'s help and spawn prompt). Running seats should start adding the fields. A line without them still works and leaves the tab's colour as it is.
- A seat's tmux tab takes its colour from that line: green at `open=0`; red, orange or yellow by `worst=`. Only a whole STATUS line, with its fields in order from the line's start, counts. Typing in the pane still turns the tab green until the next STATUS line. This replaces colouring from the criticality markers in a reply.

## [1.6.0] - 2026-11-16

### Added

- `/open-questions` in the lead's pane begins with a `Pane | Waiting for you` table: the lead's own row first, then one row per seat waiting for the operator. The lead may run `team.sh status` for it.
- One layout for every question, in the template and in rule 6: a `---` line before each, a bold `Issue:` title line instead of a Markdown heading, and blank lines around the ❓ line.
- `team.sh status` flags a seat whose input box holds text (`[input box holds text]`) or cannot be read (`[input box unreadable]`), and says so at the end of the seat's queued messages.
- A seat's tmux tab is coloured by what waits on the operator: red, orange or yellow after the most critical question in a reply that asks any; green once the seat says nothing is open, or once the operator types in its pane (not a `Lead:` message, not a `/command`). A tab keeps its colour until the seat's next activity.
- While a seat works, its window carries the tmux option `@working`. The tab format in the README shows it as ⚡ after the tab's name.

Seats pick up the extension at their next start or `/reload`. Rerun `install.mjs` after taking this release, and add the README's two tab-format lines to your tmux config for ⚡.

## [1.5.0] - 2026-11-16

### Added

- Rule 6: above each question, one plain-text line gives its criticality and what it blocks, starting with 🔴 high, 🟠 medium or 🟡 low. Several questions are ordered most critical first, then by what each blocks soonest, then with related ones together, as `/open-questions` prints them.
- `/o`, a shortcut for `/open-questions`, input box prefill included. It is not listed in command completion.

### Changed

- `/open-questions` with nothing open prints `Open questions for the operator: NONE`, and the pane shows the whole line green. A line that is exactly `No questions of mine are open.` shows green too.

## [1.4.0] - 2026-11-16

### Added

- `/open-questions`, a pi prompt template (`tools/prompts/open-questions.md`). Typed in a seat's pane, it makes the seat print there every question it has put to the operator that is still unanswered, in full in rule 6's form, or `none`. It orders them by criticality, then by what each blocks soonest, then keeps related ones together. Each question has a criticality line starting with 🔴 high, 🟠 medium or 🟡 low.
- `tools/extensions/open-questions.ts`, its pane side. It colours each criticality line to match its marker, display only. After a turn started by `/open-questions`, it fills the empty input box with one row per question, `<marker> <criticality> · <ID>: Yes`, to edit and send. `team.sh` messages wait while the box holds those rows.
- `install.mjs` installs both: the template into `~/.pi/agent/prompts/` and the extension beside `guards.ts`. Rerun it after taking this release, then `/reload` running sessions.

## [1.3.1] - 2026-11-15

### Changed

- Rule 6's issue form: "Solutions, each with its effort" becomes "Solutions, effort and tradeoffs": each solution names its effort and its tradeoffs.

## [1.3.0] - 2026-11-15

### Added

- Rule 6: every issue or finding put to the operator states, in plain words: Done, Expected, Instead, Impact, Root cause (hypothesised), and Solutions, each with its effort; then the ❓ question and the ➡️ answer.
- `.githooks/pre-commit`: a commit touching `tools/extensions/` or `tests/guards/` runs both guard tests and is refused if either fails.
- `tests/merge-ready`: tests `tools/merge-ready` with real commits in a scratch repository.

### Fixed

- `tools/merge-ready` counts only the branch's own changes since the live run. It compares HEAD with integration merged into the live-run commit, so what merging integration in brought no longer refuses the merge, and a conflict counts only when it is under the given code paths.

### Changed

- Every script starts with `#!/usr/bin/env sh` (`team.sh`, `src-pre-commit`, `wiki-pre-commit`, `merge-ready`, `.githooks/pre-commit`, `tests/merge-ready`).

## [1.2.0] - 2026-11-15

### Added

- `team.sh doctor`: checks the host dependencies listed in `tools/expect`, one per line (`sysctl`, `nonempty`, `sshcontrolpath`, and `jail <name>` for the fix block), and prints one block of fixes for the host. A failed read is a failure.
- `team.sh status` lists every queued message as `QUEUED <target> <age>m: <text>`. `send`, `go` and `report` say when the target pane is busy; pi then holds a typed message as steering until the agent's current step ends.
- `team.sh report` registers each `❓ <ID>` it carries in `tools/qids`, and refuses a report that reuses an ID registered to another seat, naming the owner.
- `tools/merge-ready <worktree> <live-run commit> <code paths>`: refuses when integration is not in HEAD, or when the code paths changed since the live run.
- `tools/wiki-pre-commit`, the wiki's commit guard against a file emptied by accident. Link it as `docs/kickoff.md` step 4 says.
- `tools/extensions/guards.ts`, one pi extension with two `tool_call` guards: sibling-guard refuses a `bash` call issued in the same message as a `write` or `edit`, and heredoc-guard refuses a heredoc whose delimiter is not a plain name or appears more than once. `tools/extensions/install.mjs` installs it and replaces a separately installed `heredoc-guard.ts`. Its tests are `tests/guards/`. To install it, follow the README's "Guards" section and `docs/kickoff.md`'s new step. (Added to this section after the release: the guards were merged into integration by another seat and shipped in 1.2.0 without an entry.)
- Rule 9: the lead runs `merge-ready` and names the live run's commit in the authorisation. Team mechanics: check `team.sh status` for `QUEUED` before saying a seat missed a message, and run `team.sh doctor` after a host reboot.

### Changed

- `TEAM_WAIT` defaults to 14400 s (4 h), up from 1800 s, before an undelivered message moves to `failed/`.
- The empty-file checker moves from `.githooks/check_empty_files` to `tools/check_empty_files`, shared by this repo's hook and the wiki's.

## [1.1.0] - 2026-11-15

### Added

- Rule 9: just before merging, a seat merges the integration branch into its branch and resolves conflicts there, flagging a diverged shared file to the lead; its ready report names the commit of its last live run, and code changed since then runs live again. The flow's step 7 in `docs/index.md` says the same.
- Rule 10: a claim the lead passes on about state names the whole read it rests on; any other read is passed on as unverified, and a brief carries such facts as checks to run.

## [1.0.0] - 2026-11-15

The `matias-pizarro/skills` repo becomes `matias-pizarro/agentic_workflow`, and takes in the playbook, which until now was its own repo, with its history.

### Added

- The playbook: `docs/index.md` (what the process is and why each rule exists), `docs/kickoff.md` (the first hour), `docs/rules.md` (the rules, for agents).
- `tools/team.sh`, the team script, and `tools/src-pre-commit`, the lead's commit guard.
- `.githooks/pre-commit`, for clones of this repo: refuses a commit that empties a file by accident; turn it on with `git config core.hooksPath .githooks`.
- `README.md`: the layout, how a project uses the repo, what each version number means, and how to cut a release.

### Changed

- The repo's name: install skills with `npx skills@latest add matias-pizarro/agentic_workflow ...`. GitHub redirects the old name; reinstall a skill from the new name to update its lock file entry.
- The playbook's paths. A project that cloned the playbook as `<root>/playbook` must:
  - clone this repo at `v1.0.0` as `<root>/agentic_workflow` (`docs/kickoff.md` step 4);
  - point the rules line in its `AGENTS.md`, and every task file, at `<root>/agentic_workflow/docs/rules.md` (was `<root>/playbook/RULES.md`);
  - repoint the team script and the commit guard, wherever they are linked or copied from, to `<root>/agentic_workflow/tools/` (was `<root>/playbook/tools/`), and run `team.sh selftest` through the new path.

### Fixed

- `skills/review-loop/SKILL.md`, emptied by a commit on main (8639493), is restored.

[1.10.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.10.0
[1.9.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.9.0
[1.8.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.8.0
[1.7.1]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.7.1
[1.7.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.7.0
[1.6.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.6.0
[1.5.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.5.0
[1.4.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.4.0
[1.3.1]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.3.1
[1.3.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.3.0
[1.2.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.2.0
[1.1.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.1.0
[1.0.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.0.0
