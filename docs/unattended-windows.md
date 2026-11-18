# Unattended windows

How the lead runs work while the operator is away: a night, or a day out. [rules.md](rules.md) rule 15 says what binds every agent during one; this page is the lead's procedure around it. Only the operator opens, starts, aborts or ends a window, with four commands typed in the lead's pane. Without them there is no window, and every agent works under the attended rules, waiting for the operator's answers as usual.

## The commands

Each acts only when the operator types it in the lead's pane, and arrives stamped with its time. Typed in a seat's pane, it is refused there and does nothing.

| Command | Valid | The lead then |
|---|---|---|
| `/unattended-window <intent>` | no window open or being grilled | takes `<intent>` as the statement of what the window is for and runs the opening grill |
| `/abort-unattended-window` | only while the grill runs, before the start | drops the grill; nothing was started |
| `/start-unattended-window` | only after the grill | starts the window on the terms settled |
| `/end-unattended-window` | only while a window runs | ends it: stop and hold, then the morning report |

## Opening: the grill

The lead turns the intent into terms with a short grill, its questions in rule 4's and rule 6's form, under its own question prefix. It is free to propose whatever the intent suggests; rule 10 still holds: each `➡️` is the smallest option that meets the operator's words, and anything beyond them is labelled `widens:`. The grill settles at least:

- **The expected end.** A guide for planning; only `/end-unattended-window` ends the window.
- **Where.** The projects, accounts and components the window may touch, and the seats taking part.
- **Production changes**, and on which components.
- **Spend.** The cap the window's run-rate stays under.
- **Outward steps** beyond the standing gos: pushes, releases, publication (rule 13).
- **Merges on assumptions.** None by default; the grill may name a branch that may merge resting on unconfirmed assumptions.
- **The queue.** Per seat, where its next independent item comes from when its work is blocked (e.g. the board's Ready column, a named list).
- **Recovery** allowed beyond a change's own undo, e.g. a server reboot.
- **Relaxations.** Anything loosened for the window, each with its undo and who runs it.

The floor in rule 15 is not on the list: no answer grants it.

The lead then repeats the terms back as one block, writes them at the top of the window's ledger, and waits for `/start-unattended-window`.

## Start

The lead records the start time in the ledger and sends each taking-part seat one message: the window has started, rule 15 applies, the terms and the ledger are at `<path>`. Relaxations are made first, each as a ledger line with its undo.

## The ledger

One page per window in the project's wiki, `window-<yyyy-mm-dd>-<hhmm>.md` (the start's date and time), linked from `index.md`. At the top: the intent and the grill's answers, each with the operator's words and time; the terms block; the start, and later the end. Then one line per change, written by the lead from the seat's report at the time of the change:

| # | Time | Seat | What changed | Where (commit, resource, host) | Rests on (assumption IDs) | Undo (steps; who) | State (the read; its time) |
|---|---|---|---|---|---|---|---|

A later state is added as a dated note on the line; the old one stays (rule 11). A floor stop and an incident each get their own line. Under the table, **To undo regardless**: each relaxation, and each key or secret made (where, what), with who undoes it and the read that will show it done.

## During the window

- The lead writes each reported ledger line, and otherwise waits for reports: nobody polls.
- On a 🔴 report (a change's own undo run after a failing check), the lead tells every seat working on that component to hold, and marks the line.
- A seat that has nothing left, its queue included, says so in its report and stops.

## End: `/end-unattended-window`

1. **Stop and hold.** The lead tells every taking-part seat that the window has ended. Each finishes or safely stops its current step, starts nothing new, and reports what is live. No agent rewinds anything on its own.
2. **The morning report**, printed in the lead's pane once the seats have reported, in this order, pointing at panes and the ledger rather than pasting them, its first screen readable in about two minutes:
    1. **🔴 Incidents**, each in rule 6's issue form, with what was undone and what is held.
    2. **Floor stops**: work that reached the floor and waits for the operator.
    3. **What changed**: the ledger by component, each line live or branch-only, its undo, and the assumption IDs it rests on, so rejecting an assumption names what to rewind.
    4. **Waiting for you**: the `/open-questions` table (pane, IDs), most critical first, then each pane's assumptions, grouped so each pane can take "yes to all".
    5. **Not done**: the queue items left, and why.
    6. **To undo regardless**: the ledger's list.
3. **Close.** For each open group in "To undo regardless", such as rotating the window's keys, the lead asks `❓ CS-Qn – Size <the undo> as <tier>?` (rule 1). Each group stays in every morning report and every lead handoff until a read closes it. Nothing is rotated unattended.

The window's grants lapse at its end: from then, the attended rules apply, and the rewind of any change is the operator's choice, made from section 3.
