# Changelog

Every release of this repo, newest first, in the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as `README.md` defines it for this repo: a major release asks a project to act, and its entries say how.

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

[1.4.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.4.0
[1.3.1]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.3.1
[1.3.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.3.0
[1.2.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.2.0
[1.1.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.1.0
[1.0.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.0.0
