# Check-out template

Before `team.sh retire <seat>`, the seat writes its check-out with this file's path (the operator, 18 Nov 2026, LD-Q13, AW-Q85), to `<root>/wiki/sources/checkouts/<yyyy-mm-dd>-<seat>.md`, and commits only that file in the wiki. The lead then retires the seat. A check-out closes a seat for good: it is for whoever later takes up the area, and for retros. A seat that goes on in a new session is refreshed instead (`team.sh refresh`, its handoff template `tools/handoff.md`), not checked out.

Write it short: a few lines per section; pointers (paths, commits, question IDs), not pasted contents; no secrets.

The first line, exactly:

```
# Check-out: <seat> (<d Mon YYYY>)
```

Then one line saying when and by whom it was written, and on whose word the seat retires. Then these sections, each kept, with "None." where it is empty:

- **Brief**: the task file, with the operator's words and time, and the brief in a sentence or two.
- **Delivered (with commits)**: what was merged, released, deployed or written, each with its commit, tag or path.
- **Challenges**: what made the work harder than planned, and what was done about it.
- **Key events (dated)**: the decisions, answers and turns of the work, each with its date and time.
- **Learnings**: what the next seat in this area, or the playbook, should take from it.
- **Follow-ups for a successor (pointers)**: what is left: open questions, backlog items, branches or worktrees still around, each with where it is.
