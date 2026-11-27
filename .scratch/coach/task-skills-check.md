Ceremony: script (the operator, "CS-Q112 yes", 27 Nov 2026 23:31)

# Task: a daily check of the global skills

Seat: coach. Branch: `feat/skills-check` in agentic_workflow, worktree `/agents/sessions/freebsd/sandbox/worktrees/aw/feat/skills-check`, from `integration` e27a910. Relayed by the lead, 27 Nov 23:31 (CS-Q112 (a)); the operator's words, coach pane 23:29: "the l;eadshould probably check skills are up to date once a day".

## What it changes

1. `tools/skills-check`: read-only. For each global skill in `~/.agents/.skill-lock.json`, compares its `skillFolderHash` (the git tree of its folder at install) with the same folder at its source's default branch, read by a shallow, blob-less clone; prints each skill behind its source; exit 0 when none, 1 when any, 2 when a read fails. It changes nothing: `npx skills update -g` has no dry run.
2. rules.md Team mechanics: the lead checks the global skills daily, prompted by the wiki's crontab; updates only on the operator's go; then asks the seats to reload when any changed.
3. The crontab line for `/agents/sessions/freebsd/sandbox/wiki/crontab`, given to the lead, prompting it with `team.sh send`.

Out of scope: tools such as reladraw (CS-Q112).

## Checks

- Live first: `skills-check` against the real lock file and GitHub; a copy of the lock with one hash changed reports that skill; an unreachable source exits 2. The crontab command, run with cron's environment against a throwaway tmux server.
- **If it fails:** the skills are checked by hand, as before.
- Review: one `code-review` pass.
