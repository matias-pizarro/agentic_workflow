Ceremony: script (the operator, "CS-Q108: Yes", 27 Nov 2026 22:57)

# Task: the doc-freshness mechanism

Seat: coach. Branch: `feat/doc-freshness` in agentic_workflow, worktree `/agents/sessions/freebsd/sandbox/worktrees/aw/feat/doc-freshness`, from `integration` e27a910 (v2.20.0). Relayed by the lead, 27 Nov 22:58 (CS-Q108 (a)). Source: the research `research/doc-freshness` a9100a8, options (a), (c) and (d), taken by the operator ("CO-Q10: yes", 27 Nov 22:30).

## What it changes

1. (a) `tools/merge-ready` warns, without changing its exit status, with the docs that still state a fact the branch removed: a name (hyphenated or dotted) or an IPv4 address on a removed line of the branch's diff, gone from every file at the head but the docs, and still in a doc (`*.md`, not `.scratch/`) of the repo or of each directory in `MERGE_READY_DOCS` (for the playbook's own pages). With a test.
2. Rule 9: when merge-ready lists docs, the lead's authorisation waits on Docs' (librarian's) check of them and names it.
3. (c) and (d), rule 16: Docs keeps what is written current without writing it; Architecture sends Docs the names, addresses and interfaces each merged change to the constants, an ADR or the component map changes; Docs reads the docs against the sources of truth weekly and sends each stale line to its owner.
4. (d) the weekly prompt: a line for the wiki's `crontab` (the lead's file), sending librarian the weekly drift read through `team.sh send`, logged to `tools/spool/cron.log`.

## Checks

- Live first (rule 2): merge-ready on real branches (a scratch repo replaying the Caddy case; this repo's branches); the crontab line's command against a throwaway tmux server.
- **If it fails:** staleness is found only by librarian's sweeps, as before.
- Review: one `code-review` pass. Then merge-ready, and the release on the operator's word.
