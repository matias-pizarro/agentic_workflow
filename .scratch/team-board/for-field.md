# The `for=` STATUS field: the rule text team-board needs

Decided by the user: TB-Q2 (b), "b", team-board pane 20 Nov 2026 11:47 (a new STATUS field, changing rules.md); TB-Q3, "placed after `state`", 11:48. Owner of the edit: agentic-workflow, routed by the lead.

## 1. docs/rules.md, Team mechanics, first bullet

In the STATUS template, insert `[for=<PM|lead|seat-name>] ` between `state=<…>` and `open=<n>`, so it reads:

`STATUS seat=<name> state=<working|waiting-for-PM|waiting-for-seat|ready-for-lead|blocked|idle|done> [for=<PM|lead|seat-name>] open=<n> [worst=<high|medium|low>] [ask="<one sentence>"] [pointer=<path or commit>]`

Then add, after the sentence defining `worst`:

`for` names who you wait for: `for=PM` with `waiting-for-PM`, `for=lead` with `ready-for-lead`, and with `waiting-for-seat` the seat you wait for (the first, if several); leave it out in the other states.

## 2. tools/team.sh, compose_prompt (the spawn prompt's protocol line)

The same template change in the line `STATUS seat=$1 state=<…> open=<n> …`, so new seats learn the field from their first message.

## 3. CHANGELOG Act line for seats

From your next STATUS line, after `state=`, add `for=PM`, `for=lead` or `for=<seat>` when waiting; `/reload` once idle (open-questions.ts reads the field and publishes the seat's fields to tmux).

## Order

The release carrying this text must also carry team-board's `open-questions.ts` change, which accepts `for=` between `state=` and `open=`: today's extension stops reading a STATUS line with anything there, and the seat's tab stops updating.
