# Handoff template

`team.sh refresh` asks a seat for its handoff with this file's path (the operator, 18 Nov 2026, RF-Q7). The next session holding the seat reads the handoff first, whole, and knows only what it says and what it points to. Write for that reader: current state, not history; pointers (paths, commits, question IDs), not pasted contents; no secrets.

The first line, exactly as the request gives it:

```
# Handoff: seat <seat>, <d Mon YYYY> <hh:mm>
```

Then these sections, each kept, with "None." where it is empty:

- **What the seat owns**: the component, repo, branch and worktree; the ticket and its tier, with the operator's words.
- **Read first**: the files the next session reads before acting, in order (rules.md, the ticket, the perimeter, the README of the work), each with why.
- **State as it stands**: what is merged, pushed, released, deployed, each with its commit; what was last run live, on which commit, with its result.
- **Work in progress**: what is half done, where (files, branch, uncommitted changes), and the next step.
- **Open questions**: every question to the operator still unanswered, in full, in rule 6's form, under its ID, as `/open-questions` prints it, so the next session asks it again under the same ID. Assumptions awaiting the operator's confirmation count.
- **Waiting on the operator**: steps only the operator can take, not questions.
- **Waiting on others**: messages to the lead or other seats awaiting an answer; gos given and not yet acted on, with their words and times.
- **Background work**: subagents, jobs or live runs started by this session that may still finish, and where their output lands. A run that would report to this session is a reason to answer `REFRESH-UNADVISABLE` instead.
- **Cleanup owed**: worktrees, branches, sandboxes, keys or temporary files to remove, and on whose word.
- **How to work here**: commands, timings and pitfalls met that are not written elsewhere.
- **The lead only, when the seat is the lead**: each seat's last known state and what it waits on; messages and gos in flight; tasks drafted and not yet spawned; the wiki pages changed and not yet committed.
