---
description: Print, in this pane, every question you asked the operator that is still unanswered
---
List every question you have put to the operator in this session that the operator has not yet answered. Print them here, in this reply. Do not write them to a file, and do not run any tool for this.

A question is answered when the operator replied to its ID (or to "yes to all", "yes" to a single open question, or their own words for it), here in your pane or relayed by the lead as the operator's words ("the user's go", "the operator, <time>: ..."). A question you withdrew, or that was overtaken by a later decision of the operator's, is not open: leave it out. When you cannot tell whether one was answered, list it and say so.

Order them:
1. most critical first: high, then medium, then low, by what goes wrong, and for whom, while it stays unanswered;
2. then, among equally critical ones, the one blocking work soonest first (your next step, another seat's, a merge or a release), and the one that blocks nothing yet last;
3. then, among equally blocking ones, keep related questions together (same topic, same ticket, or one answer depending on another), not in random order.

Above each question, print one line with its criticality and what it blocks, starting with 🔴 for high, 🟠 for medium or 🟡 for low, as plain text (not in backticks), e.g. `🔴 high · blocks the production switch` or `🟡 low · blocks nothing yet`. The pane colours that line's text to match.

Print each open question in full as it stands now, updated to what you know at this moment, not as first worded:
- for an issue or finding (rules.md rule 6): **Done**, **Expected**, **Instead**, **Impact**, **Root cause (hypothesised)**, **Solutions, effort and tradeoffs** (each solution with its effort and its tradeoffs), then the `❓ <ID> – <question>?` line and the `➡️ <recommended answer>` line, worded so "yes" accepts it;
- for any other decision: one or two lines of context, then the `❓` line and the `➡️` line.

Start with one line: `Open questions for the operator: <n>`. If there are none, print only `Open questions for the operator: none`. If part of this session was compacted and you cannot see whether some questions were answered, say so on that first line. End your turn with your usual STATUS line.
