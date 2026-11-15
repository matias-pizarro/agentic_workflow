# Rules

Process rules for every agent on a team run by this playbook: the lead, seats, workers and reviewers. "The operator" is the human who decides. Each rule's reason is in [index.md](index.md) under the same number; read it when a case is unclear. `<root>` is defined at the top of index.md.

0. **Precedence.** Where a skill prescribes broader or automatic action than these rules (fixing every finding, a review the tier doesn't call for, acting on retro candidates, `review-loop`'s `auto` mode), these rules and the ticket's tier govern. Run `review-loop` without `auto`.

1. **Tier.** Every ticket's ceremony tier, `checklist`, `script` or `full` (`none` for research, retros and write-ups), is the operator's choice, made before the ticket is written. The lead asks `❓ CS-Qn – Size <work> as <tier>?`, quotes the operator's words, says what each tier builds and recommends the lowest those words allow; a higher tier names its reason. The task file's first line is `Ceremony: <tier> (the operator, "<words>", <date> hh:mm)`. Build and review what the tier says and no more:
    - `checklist`: a doc of numbered commands, one line each on what it does; `**If it fails:** <one sentence>`; no review.
    - `script`: a plain script relying on each step's own rerun safety; `**If it fails:** <one sentence>`; one `code-review` pass, the review loop only on the operator's words.
    - `full`: acceptance criteria; a `## Failure modes` table, one row per step: what a failure there leaves and what the operator is told; every read of state says yes, no or failed, and a failed read is never taken as absent; the review loop.

    Adopting existing code is a ticket of its own.

2. **Live first.** Verify every ticket by running it for real on an expendable host (a disposable container or jail, a test VM, a cloud sandbox), by trial and error, before any review. Throw the host away after. Verification is real runs: build no fixture, fake or dry run where a live test is practical. A fixture standing in for a tool's output is copied from a real run and says where from. When a live run is impractical, ask the operator for the exception as its own question.

3. **Compromised by design.** Treat every sandbox and agent, yourself included, as able to do the worst its environment allows. Contain by disposable environments and isolation: tests run in a child container or jail. Expose only what is expendable. Seats sharing one cloud account each use their own seat name as their project name for cloud sandboxes (e.g. `sandbox cloud create <seat>`), so each gets its own servers, disks, keys and known_hosts. Write files with the write and edit tools, never through a shell heredoc.

4. **Questions.** Each question is a block: `❓ <ID> – <question>?`, the context under it, then `➡️ <recommended answer>`, worded so `yes` accepts it. IDs are unique for the life of the project: a prefix per thread plus a number. Ask for decisions only; look facts up yourself. Record `ok` as "trusts the recommendation without full understanding", and re-explain that decision before anything hard to reverse follows from it.

5. **Words and time.** A deliberate choice (the operator accepting a risk or cost) is recorded where the project keeps decisions, quoting the operator: `(the operator, "<words>", <date> hh:mm)`. A go relayed from the operator is quoted the same way. Your own choice goes to review, never under the operator's name. Each edit you claim names a commit whose diff touches the file you name; an entry that changes nothing says "No change".

6. **Visible findings.** Every review finding reaches the operator. Each round's summary opens with `<topic> · <loop> round k · findings so far F · questions so far Q`, rates each finding's impact (high, medium or low: what goes wrong and for whom if it stays) and effort (very low, low, medium or high; very low is a word or a line, cheaper than a backlog entry), and recommends: fix for the important few; fix now for low impact at very low effort; the backlog (`.scratch/backlog.md`: date, item, impact, source, the operator's words) only for the rest, low impact with real effort. Every finding is answered by the operator: fix, delete or backlog.
    - Reviewers are read-only and run on a different model from the writer's; the agent running the loop puts the over-build, impact and drift checks into the reviewer's prompt.
    - Sweep the class: after fixing a finding, search for its sibling instances, fix them in the same turn and name them in the response.
    - A fix that changes a check instead of the code follows rule 14.

7. **Drift.** A finding in lines an earlier round of the same loop added or changed, or a second round running finding gaps in the same check, is drift. A round with drift opens with `❓ DRIFT-Qn`, naming the findings and the rounds they trace to, with three options in this order: step back and delete or simplify; stop, backlog the rest; continue. Drift is a signal to raise, every time. The turn cap is 15 rounds per loop, a checkpoint: at 15, and after each further 5, the lead asks the operator whether to extend.

8. **Over-build.** Every review looks for code, checks, options, tests or criteria that the operator's scope or a simpler design makes unnecessary, above all a check of state before a step already safe to rerun, and weighs it the same as a gap, naming what to delete. Every finding's question offers delete; recommend delete wherever it answers the finding as well as a fix.

9. **Live before merge.** A branch merges into the integration branch only after its live checks pass on a real host, with `git merge --no-ff`. Just before merging, the seat merges the integration branch into its branch and resolves any conflict there, flagging to the lead a shared file that diverged; its ready report names the commit its live checks last ran on, and code changed since then runs live again. A visual change is shown to the operator as a render, and their feedback taken, before anything is committed.

10. **Lead: delegate, stay small.** The lead decides nothing for the operator, edits nothing in the project, and writes only the wiki and task files; seats make every edit and commit. A claim the lead passes on about state (exists, absent, intact, tested, the cause of a failure) names the read it rests on: the whole command output, or a seat's report and its commit. A truncated, partial, remembered or second-hand read is passed on as `unverified: <claim>; <who> checks`, and a brief carries such facts as checks to run. In every scope question:
    - `➡️` is the smallest option that meets the operator's own words;
    - an option beyond them is labelled `widens: <what it adds>` and is recommended only when a named security risk forces it;
    - a request for something reusable, shared or a framework first gets: which second project or caller uses it, and when? Without an answer, the work stays where it is;
    - when a step is safe to rerun, recommend running it, with no check before it;
    - an agent's offer to stop or defer goes to the operator as offered; the lead recommends against it only by naming the tier's reason.

11. **Dated wiki.** The lead keeps the wiki as history: every claim dated, every claim about code citing its commit, a change added as a new dated line with the old one marked superseded. Read `index.md` and the pages it names before a decision. Commit only the paths you changed. Use an existing shared wiki where there is one; keep `index.md` linking every page; cite sources, never edit them; lint for contradictions, orphans and stale claims periodically. Specs, ADRs and ticket bodies, unlike the wiki, state the current decision only; git and the wiki hold their history.

12. **Retros.** About one session in five, those where something went wrong first, gets a retro: read-only, proposing environment changes (hooks, standards, skills, the team script) in order of severity, each with its cost. The operator chooses.

13. **Outward steps.** A push, a publication, spend beyond the stated cap, or content sent off the machine waits for the operator's go. A standing go the operator gave for one operation (e.g. pushing the integration branch after a lead-authorised merge, one ref, the push-time secret scan passing) counts as their go for that operation only; the project's own notes list every standing go, with the operator's words and time.

14. **Checks changed, not code.** Any change to a check, test, fixture, check setup or acceptance criterion, by anyone (seat, worker, a fix driven by review or by a live run), at any time:
    - opens its report with `⚠️ CHECK CHANGED, NOT CODE`, names the check, its old and new assertion and why, and goes to the operator as `❓ CHK-Qn`; a pass resting on it counts only once the operator answers;
    - a new or changed check is first shown to fail on the broken code; only then does its pass count.

    Why: changing a check to make it pass is the easiest way to hide a real failure, and checks are the source of truth, so a weakened check silently weakens everything resting on it. Examples: a live check's timeout relaxed until it passed; a bridge step that passed on code failing open.

## Team mechanics

- End every turn with one line: `STATUS seat=<name> state=<working|waiting-for-PM|waiting-for-seat|ready-for-lead|blocked|idle|done> [ask="<one sentence>"] [pointer=<path or commit>]`. "PM" is the operator.
- The team script is `<root>/agentic_workflow/tools/team.sh`. After each Pi upgrade, run `team.sh selftest`; `team.sh status` lists any message stuck in `failed/`.
- Seats report with `team.sh report "<name>: <one or two sentences> <pointer>"`, then end the turn. The lead sends with `team.sh send`, and relays a go only with `team.sh go`.
- Messages, task files and reports carry pointers (a path or a commit), never pasted contents.
- The lead's session stays free for the operator: long work runs in seats and background subagents, and nobody waits in a polling loop.
- Each turn the lead checks `date`, `team.sh status` and the repos' recent commits.
