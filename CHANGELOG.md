# Changelog

Every release of this repo, newest first, in the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as `README.md` defines it for this repo: a major release asks a project to act, and its entries say how.

## [Unreleased]

### Added

- `/refresh <seat>…|all|lead`, typed in the lead's pane, and `team.sh refresh`: hand a seat, or the lead, to a new pi session in the same pane through a handoff (`tools/handoff.md`), deferred while the seat is busy, typing or has a message queued, refused when the seat answers it is unadvisable; the lead's pane is free at once and gets one report per seat.
- The session ledger, `tools/ledger`: `ledger.ts` logs every pi session's start and stop with its seat, session id and session name; `team.sh refresh` logs its steps. Add `tools/ledger` to the wiki's `.gitignore` beside `tools/agents`.
- `team.sh spawn` names each session `<seat> <YYYY-MM-DD hh:mm>`.

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
