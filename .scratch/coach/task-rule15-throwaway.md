Ceremony: docs (the operator, "CS-Q116 yes", 28 Nov 2026 01:27; rule 15)

# Task: rule 15's stop spares a seat's own throwaway

Seat: coach. Branch: `docs/rule15-throwaway` in agentic_workflow, worktree `/agents/sessions/freebsd/sandbox/worktrees/aw/docs/rule15-throwaway`, from `integration` c0b9962 (v2.22.0). Relayed by the lead, 28 Nov 01:28 (CS-Q116 (a)). The operator's words, forgemaster's pane, 28 Nov 01:22: "we should not stop at first failure. Tell coach through lead we need to review this rule if it actually states that".

## What it changes

- `docs/rules.md` rule 15, the bullet "when a step leaves a check failing ...": the stop applies to a change on anything the window did not create for that seat alone; on an expendable host the seat made for the window, it keeps trying fixes and reruns on its own, within the grill's time and spend caps, and destroys the host after; a fix found there reaches anything lasting only as a new change under the stop.
- `docs/unattended-windows.md`, the 🔴 report line, to match.
- `docs/index.md`, rule 15's reason, one clause.

## Checks

- Live check: no docs build; md-html renders of the changed pages, named to the operator.
- **If it fails:** rule 15 still stops trial and error on a seat's throwaway at the first failing check.
- Review: the operator reads the diff. Then the release, on the operator's word.
