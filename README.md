# agentic_workflow

A way to run software work with a team of [Pi](https://github.com/earendil-works/pi) agents (one lead and several seats, with you deciding everything that matters), and the scripts and skills it runs on.

- **`docs/`**: the playbook. Start at [docs/index.md](docs/index.md): what the process is and why each rule exists; [docs/kickoff.md](docs/kickoff.md), a checklist for the first hour; [docs/rules.md](docs/rules.md), the rules worded for agents.
- **`tools/`**: `team.sh`, the team script; `src-pre-commit`, the lead's commit guard; `extensions/guards.ts`, a pi extension refusing tool calls known to go wrong (below).
- **`skills/`**: agent skills, one directory each.
- **`CHANGELOG.md`**: what each release changed, and what a project must do to take it.

## Use it in a project

Clone it beside the project, at a release tag, and point your agents at it by path ([docs/kickoff.md](docs/kickoff.md) has every step):

```sh
git clone --branch v2.2.0 https://github.com/matias-pizarro/agentic_workflow.git <root>/agentic_workflow
```

Install a skill globally with the [skills CLI](https://github.com/vercel-labs/skills), which asks which agents to install it for:

```sh
npx skills@latest add matias-pizarro/agentic_workflow -g --skill <name>
```

- **review-loop**: commits pending work, has Codex review one topic under `.scratch/`, grills you through each finding and records the response, turn after turn until a review has no findings. Needs `codex` (logged in) or `pi` with `OPENAI_API_KEY`, and the `grilling` and `domain-modeling` skills, which the CLI does not install with it: `npx skills@latest add mattpocock/skills -g --skill grilling domain-modeling`.

## Guards

`tools/extensions/guards.ts` is one pi extension with one handler per guard:

- **sibling-guard** refuses a `bash` call issued in the same assistant message as a `write` or `edit`. pi runs one message's tool calls at the same time, so the command could read the file half-written; it is told to run in the next message. It also refuses a `bash` call beside another `bash` call when either runs a git step that changes state (commit, merge, push, checkout, add, ...) or `merge-ready`.
- **time-stamp** starts each message typed in the pane, other than a `/command`, with its local time, `[17 Nov 12:59] `, so a quoted time is the stamp, never an estimate. Messages `team.sh` types are stamped with their delivery time.
- **heredoc-guard** refuses a `bash` call holding a heredoc whose delimiter is not a plain name, or whose delimiter line appears more than once, since bash would end the heredoc early and run the rest of its body as shell.

Install it for your user, after backing up pi's settings (both steps are safe to rerun; on a rerun, `cp -n` keeps the first backup and exits 1):

```sh
cp -n ~/.pi/agent/settings.json ~/.pi/agent/settings.json.bak-guards
node tools/extensions/install.mjs
```

This copies it into `~/.pi/agent/extensions/`, which every pi session loads at its start, and lists it in `settings.json`'s `subagents.defaultSubagentOnlyExtensions`, which foreground subagents load. Running sessions pick it up at their next start or `/reload`, and the install ends by listing the tmux panes running pi that need it. It also removes `heredoc-guard.ts` and its entry, installed separately before it became a handler here. Its tests: `node tests/guards/run.mjs` and `tests/guards/heredoc/run_tests`.

The same step copies the prompt templates in `tools/prompts/` into `~/.pi/agent/prompts/`. Today that is `/open-questions`, or `/o` for short: typed in a seat's pane, it makes the seat print, in that pane, every question it has put to the operator that is still unanswered, each in full in rule 6's form, or `none`. Its pane side, `tools/extensions/open-questions.ts` (installed by the same step), colours each question's criticality line (🔴 high, 🟠 medium, 🟡 low) and then fills the empty input box with one row per question, `<marker> <criticality> · <ID>: Yes`, to edit and send. Messages from `team.sh` wait while the box holds those rows. It also colours the seat's tmux window tab from the STATUS line that ends each turn (`docs/rules.md`, Team mechanics): green at `open=0`; red, orange or yellow by `worst=` when questions are open. A turn without that line leaves the colour as it is, and the tab turns green once you type in the pane (not a `Lead:` message or a `/command`), until the seat's next STATUS line. At the end of each turn it registers each new `❓ <ID>` of the reply to the seat in the question-ID registry `team.sh` names (the tmux option `@team-qids`), and warns in the pane of an ID another seat holds. It gives the seat a `reload_runtime` tool, so a seat reloads itself when the lead or the operator says so.

The same step installs `tools/extensions/draft.ts`, the `/draft <description>` command, for the main session only. Typed in the lead's pane (the pane whose tmux option `@role` is `lead`), it becomes "Task an agent with <description>.", stamped with the time, then the request to settle the task's perimeter with you using `grill-with-docs` and to propose how to follow, and to choose the seat, its working directory, branch and worktree. Typed in any other pane, it is relayed to the lead with `team.sh report`, and that seat carries on; if the relay fails, the pane says why and your line goes back into the input box. Its tests: `node tests/draft/run.mjs`. It also installs `tools/extensions/unattended.ts`, the four unattended-window commands (`docs/unattended-windows.md`, rule 15), for the main session only: `/unattended-window <intent>` opens the lead's grill, `/abort-unattended-window` drops it before the start, `/start-unattended-window` starts the window, `/end-unattended-window` ends it. Each acts only when typed in the lead's pane, in that order, and reaches the lead stamped with its time; the window's state is that pane's tmux option `@unattended` (`grill` or `open`). Typed anywhere else, or out of order, it is refused in the pane, no turn starts, and your line goes back into the input box; an unknown value in `@unattended` refuses every command. To reset the state by hand (a turn that failed after the command, or a corrupt value): `tmux set -pu -t <the lead's pane> @unattended`. Its tests: `node tests/unattended/run.mjs`. While a seat works, its window carries the tmux option `@working`; to show it as ⚡ after the tab's name, put this in your tmux config:

```
set-window-option -g window-status-format '#I:#W#{?@open, [#{@open}],}#{?@working, ⚡,}#{?window_flags,#{window_flags}, }'
set-window-option -g window-status-current-format '#I:#W#{?@open, [#{@open}],}#{?@working, ⚡,}#{?window_flags,#{window_flags}, }'
```

It also installs, for the main session only, `tools/extensions/ledger.ts` and `tools/extensions/refresh.ts`. `ledger.ts` appends a line to the session ledger, `tools/ledger` beside `team.sh` (git-ignored), each time a pi session starts or stops in a pane of the team's tmux server (not on `/reload`): `<YYYY-MM-DD hh:mm:ss TZ> <event> <seat> <session id> <session name> <detail>`, tab-separated, the seat being the tmux window's name. `/refresh <seat> [<seat>…]`, `/refresh all` or `/refresh lead`, typed in the lead's pane, hands each seat to a new session in its own pane through a handoff (`team.sh refresh`): it waits while the seat is busy, its input box holds text or a message is queued for it; asks the seat for a handoff following `tools/handoff.md`, or for `REFRESH-UNADVISABLE: <reason>`; then stops its pi and starts a new one in the same pane, named `<seat> <YYYY-MM-DD hh:mm>`, on a task file pointing at the handoff. The lead's pane is free at once; each seat's refresh reports to the lead when it ends, and logs its steps in the ledger. The handoff and task files go to the wiki's `sources/cos-archive/`, uncommitted. Typed in any other pane, `/refresh` is refused there. Its tests: `node tests/refresh/run.mjs` and `team.sh selftest`.

**If it fails:** fix the cause and rerun it.

## Versions

One version covers the whole repo, as `vX.Y.Z` tags on `main`:

- **major**: a project or a running team must act: a documented path moves, a `team.sh` command, its arguments or its spool format changes incompatibly, a skill is removed or renamed, or a rule is removed or reversed;
- **minor**: something is added that nobody must act on: a rule, a skill, a `team.sh` command;
- **patch**: nothing anyone does changes: wording, a fix behind the same interface.

## Working on this repo

Turn on the repo's hooks once per clone; they refuse a commit that empties a file by accident (`ALLOW_EMPTY=<path>` to mean it):

```sh
git config core.hooksPath .githooks
```

Their test, `tests/check_empty_files`, makes real commits in a scratch repository; run it after changing `.githooks/` or `tools/check_empty_files`.

Branches: work starts on a feature branch from `integration` and returns to it with `git merge --no-ff` once its live checks pass. `main` moves only at a release.

To cut a release:

1. Read `git log <last tag>..integration`.
2. On `integration`, add a section to `CHANGELOG.md` ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/)), naming under each Changed or Removed entry that forces a major what a project must do; pick the version by the rules above; commit it.
3. Merge `integration` into `main` and tag the merge: `git switch main && git merge --no-ff integration -m vX.Y.Z && git tag -a vX.Y.Z -m vX.Y.Z`.
4. Push `main`, `integration` and the tag once the owner says go.

MIT licensed; see `LICENSE`.
