---
description: Print, in this pane, every question you asked the operator that is still unanswered
---
List every question you have put to the operator in this session that the operator has not yet answered. Print them here, in this reply. Do not write them to a file, and do not run any tool for this, except as the next paragraph allows the lead.

If you are the lead (the chief of staff, running with TEAM_ROLE=lead), begin your reply with the summary table you print when conveying the status of the other panes: a Markdown table with the columns `Pane` and `Waiting for you`, your own row first as `(mine)` (your open question IDs), then one row per seat that is waiting for the operator, naming the question IDs waiting in its pane. Everything waiting on the operator is an open question with an ID (rules.md rule 4); a seat waiting on them without one is named in its row as `no ID: <its ask>`, and you ask it to put that as a question. List only what the operator can answer now: a question a seat has yet to ask gets no row. Seats waiting on nothing from the operator get no row. To make it current, you may run `team.sh status` (read-only) first. Then continue with your own open questions, as below.

An assumption you made in the operator's absence and recorded for them to confirm ("assumption: <ID>, confirm") counts as an open question until they confirm or reject it: list each one, under its own ID, with the answer you assumed as the ➡️.

A question is answered when the operator replied to its ID (or to "yes to all", "yes" to a single open question, or their own words for it), here in your pane or relayed by the lead as the operator's words ("the user's go", "the operator, <time>: ..."). A question you withdrew, or that was overtaken by a later decision of the operator's, is not open: leave it out. When you cannot tell whether one was answered, list it and say so.

Order them:
1. most critical first: high, then medium, then low, by what goes wrong, and for whom, while it stays unanswered;
2. then, among equally critical ones, the one blocking work soonest first (your next step, another seat's, a merge or a release), and the one that blocks nothing yet last;
3. then, among equally blocking ones, keep related questions together (same topic, same ticket, or one answer depending on another), not in random order.

Above each question, print one line with its criticality and what it blocks, starting with 🔴 for high, 🟠 for medium or 🟡 for low, as plain text (not in backticks), e.g. `🔴 high · blocks the production switch` or `🟡 low · blocks nothing yet`. The pane colours that line's text to match.

Print each open question in full as it stands now, updated to what you know at this moment, not as first worded, laid out exactly like this, with a `---` line before every question and no Markdown headings (`#`) anywhere:

```
---

🟡 low · blocks <what it blocks>

**Issue: <a short title>**
- **Done:** <what was done>
- **Expected:** <the expected outcome>
- **Instead:** <what happens instead>
- **Impact:** <high, medium or low: the absolute impact against the threshold that matters, then for whom>
- **Root cause (hypothesised):** <the cause>
- **Solutions, effort and tradeoffs:**
  - (a) <solution>: <where it lands against the threshold>. Effort: <very low, low, medium or high>. Tradeoff: <tradeoff>.
  - (b) <solution>: <where it lands against the threshold>. Effort: <...>. Tradeoff: <...>.

❓ <ID> – <question, worded so "yes" accepts the recommendation>?

➡️ <recommended answer, starting "Yes">
```

Every path in a question is given in full, from `/`, and reachable from outside the sandbox (never `/tmp`), so one click selects it, and nothing follows it but a space or the end of its line, no punctuation; a Markdown file is named by its HTML version, made or remade with `tools/md-html` after the Markdown's last change (rules.md, Team mechanics).

The `**Issue:**` line and its six bullets are for an issue or finding (rules.md rule 6). For any other decision, put one or two plain lines of context in their place. Print the skeleton's lines as plain Markdown, not inside a code block. Impact, each solution and the recommendation lead with the absolute value against the threshold that matters (a requirement, a limit, a budget, a deadline) and give the relative change only after; where no threshold is known, say so.

Start with one line (after the lead's table, if you are the lead): `Open questions for the operator: <n>`. If there are none, print only `Open questions for the operator: NONE`, as plain text (the pane colours it green). If part of this session was compacted and you cannot see whether some questions were answered, say so on that first line. End your turn with your usual STATUS line, its `open=<n>` matching the count above and its `worst=` the highest criticality listed (no `worst=` when there are none).
