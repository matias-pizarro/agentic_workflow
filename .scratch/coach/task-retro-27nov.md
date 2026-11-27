Ceremony: script (the operator, "CS-Q99 yes", 27 Nov 2026 21:22)

# Task: the 27 Nov retro's accepted changes in agentic_workflow

Seat: coach. Branch: `feat/retro-27nov` in agentic_workflow (`/agents/sessions/freebsd/sandbox/skills`), from `integration` 6a6f796. Relayed by the lead, 27 Nov 21:22 (CS-Q99 (a)).

Source: `/agents/sessions/freebsd/sandbox/wiki/sources/2026-11-27-retro.md`. The operator answered RT4-Q1, RT4-Q3 and RT4-Q4 "ok" (13:12): they trust the recommendations without full understanding (rule 4), so the release question shows the rule text.

## What it changes

1. RT4-Q1 (a): `docs/rules.md` rule 3 gains the sentence on advice to start or open anything on the host.
2. RT4-Q1 (b): rule 4 gains the sentence on a question contradicted by a newer one.
3. RT4-Q1 (c): `tools/team.sh` `doctor` gains the kind `refused <host> <port>` (passes when a TCP connect fails within 5 s), with a selftest case. The two expect lines are the lead's, after the release.
4. RT4-Q3 (a): `tools/extensions/beep.ts` marks a turn ending aborted or in error as blocked (red), with its ask, and beeps unless muted; the release's Act line asks every seat to reload.
5. RT4-Q4 (a): rule 16's Coordinators bullet gains the sentence that the operator's words on a builder's component go to that builder.

`docs/index.md` "The rules, and why" gains a line for each changed rule; CHANGELOG.md a section.

## Checks

- Live first (rule 2): `doctor` against a real expect file in the jail, a port that answers and one that refuses; `team.sh selftest`; beep.ts in a real pi pane on a throwaway tmux server, a turn that ends in error.
- **If it fails:** the rules gain the sentences anyway; doctor does not check production is closed to the jail, and a failed turn stays invisible.
- Review: one `code-review` pass, on a different model.
- Then merge-ready and the release, on the operator's word.
