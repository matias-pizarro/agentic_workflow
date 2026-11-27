Ceremony: script (the operator, "CS-Q112 yes", 27 Nov 2026 23:31)

# Task: a daily check of the global skills

Seat: coach. Branch: `feat/skills-check` in agentic_workflow, worktree `/agents/sessions/freebsd/sandbox/worktrees/aw/feat/skills-check`, from `integration` e27a910. Relayed by the lead, 27 Nov 23:31 (CS-Q112 (a)); the operator's words, coach pane 23:29: "the l;eadshould probably check skills are up to date once a day".

## What it changes

1. The check is the skills CLI's own `npx skills check -g`, read-only (a script of mine, `tools/skills-check`, was deleted on review: the operator, CO-Q24, 28 Nov 00:07).
2. rules.md Team mechanics: the lead checks the global skills daily, prompted by the wiki's crontab; updates only on the operator's go; then asks the seats to reload when any changed.
3. The crontab line for `/agents/sessions/freebsd/sandbox/wiki/crontab`, given to the lead, prompting it with `team.sh send`.

Out of scope: tools such as reladraw (CS-Q112).

## Checks

- Live first: `npx skills check -g` against the real global skills (27 Nov: 6 of 43 behind, as the deleted script found). The crontab command, run with cron's environment against a throwaway tmux server.
- **If it fails:** the skills are checked by hand, as before.
- Review: one `code-review` pass.
