# Review brief: refresh

The durable part of this topic's Codex review prompt. The `review-loop` skill fills in the commit, the prior response and its finding count, and adds a check for whatever the turn changed. Edit this file when the topic's scope or standing checks change; the skill never edits it.

## Suffix

none

## Scope

Review the code of ticket 01, `/refresh` and the session ledger, as of commit <hash> (run: git show --stat <hash>; the ticket's code is the diff from a85c70c, excluding the merge of integration ff0966e).

## Sources

Read them against:
- `.scratch/refresh/perimeter.md` (the operator's decisions RF-Q1 to RF-Q12, with their words) and `.scratch/refresh/issues/01-refresh.md` (acceptance criteria and the `## Failure modes` table)
- `GLOSSARY.md`
- `docs/rules.md`, above all rule 1's `full` tier (every read of state says yes, no or failed, and a failed read is never taken as absent), rule 3 and rule 8 (over-build)
- `tools/team.sh` (`refresh`, `_refresh`, `refresh_run` and its helpers, `spawn`'s `--name`, `publish_qids`, the selftest's `st_refresh` and `box-pi`), `tools/extensions/ledger.ts`, `tools/extensions/refresh.ts`, `tools/extensions/install.mjs`, `tools/handoff.md`, `tests/refresh/run.mjs`, `README.md`, `docs/index.md`, `CHANGELOG.md`
- `tools/extensions/draft.ts`, the sibling command whose conventions `refresh.ts` follows
- the responses in `.scratch/refresh/reviews/` (files ending in `-response.md`), the latest being for <prior hash> (left out until a topic has a prior review)

## Standing checks

Check for:
- whether each of the prior review's <n> findings is genuinely resolved, recorded as a deliberate choice, or only reworded (left out until a topic has a prior review);
- each row of the ticket's `## Failure modes` table: the code does what the row says it leaves and tells; a step that can fail with no row;
- every read of state in `refresh_run` and its helpers (pane, input box, queue, lock, handoff file, registry, pane after the respawn): it gives yes, no or failed, and a failed read never counts as idle, absent or done;
- the old session is untouched until the respawn: nothing before step 6 stops, types into or changes the seat beyond the one queued request;
- races: two runs of `/refresh all` rewriting `tools/agents`; a refresh racing `spawn`, `retire` or `revive`; the lock taken in the foreground and handed to the background run; the handoff file seen before the seat has finished writing it;
- shell quoting of every value that reaches `tmux run-shell`, `respawn-pane` and `bash -ic`: the operator's words, paths, session names;
- `ledger.ts`: a start or stop missed or doubled (reload, `/new`, resume, fork, quit by signal), and its behaviour outside a team tmux server;
- the selftest: whether each new check can fail on broken code, and whether any passes by timing alone;
- when a finding is an instance of a class (a failed read taken as absence, a missing rollback, a quoting error), every instance in the diff, listed under that one finding;
- anything that contradicts `docs/rules.md`, the perimeter or the ticket beyond the recorded deliberate choices.

## Citations

Cite every file as a markdown link relative to the review file, which sits in `.scratch/refresh/reviews/`, with the line in the link text: `[team.sh:512](../../../tools/team.sh)`. Never an absolute path, and no `:line` in the target; rendered markdown resolves neither.

## Do not re-raise

Do not re-raise, unless you have a new argument:
- the handoff and task files left uncommitted for the lead to commit (perimeter decision 5, RF-Q7);
- no force flag past unadvisable, and no automatic rollback (perimeter, Out of scope, RF-Q11);
- STATUS `state` and `open=` not used to decide deferral (perimeter decision 4, RF-Q6);
- a shallow handoff check, non-empty and first line only (perimeter decision 5, RF-Q7).
