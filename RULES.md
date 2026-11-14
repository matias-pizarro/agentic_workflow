# Rules

Process rules for every agent on a team run by this playbook: the lead, seats, workers and reviewers. "The operator" is the human who decides. Each rule's reason is in [README.md](README.md) under the same number; read it when a case is unclear.

1. **Tier.** Every ticket's ceremony tier, `checklist`, `script` or `full` (`none` for research, retros and write-ups), is the operator's choice, made before the ticket is written. The lead asks `❓ CS-Qn – Size <work> as <tier>?`, quotes the operator's words, says what each tier builds and recommends the lowest those words allow; a higher tier names its reason. The task file's first line is `Ceremony: <tier> (the operator, "<words>", <date> hh:mm)`. Build what the tier says and no more: `checklist` is a doc of numbered commands; `script` is a plain script relying on each step's own rerun safety; `full` adds criteria and a failure table per step. Every ticket carries `**If it fails:** <one sentence>`, or, in `full`, the failure table. Adopting existing code is a ticket of its own.

2. **Live first.** Verify every ticket by running it for real on an expendable host (a disposable container or jail, a test VM, a cloud sandbox), by trial and error, before any review. Throw the host away after. Verification is real runs: build no fixture, fake or dry run where a live test is practical. A fixture standing in for a tool's output is copied from a real run and says where from. When a live run is impractical, ask the operator for the exception as its own question.

3. **Compromised by design.** Treat every sandbox and agent, yourself included, as able to do the worst its environment allows. Contain by disposable environments and isolation: tests run in a child container or jail. Expose only what is expendable. Write files with the write and edit tools, never through a shell heredoc.

4. **Questions.** Each question is a block: `❓ <ID> – <question>?`, the context under it, then `➡️ <recommended answer>`, worded so `yes` accepts it. IDs are unique for the life of the project: a prefix per thread plus a number. Ask for decisions only; look facts up yourself. Record `ok` as "trusts the recommendation without full understanding", and re-explain that decision before anything hard to reverse follows from it.

5. **Words and time.** A deliberate choice (the operator accepting a risk or cost) is recorded where the project keeps decisions, quoting the operator: `(the operator, "<words>", <date> hh:mm)`. A go relayed from the operator is quoted the same way. Your own choice goes to review, never under the operator's name. Claim only edits that exist in a named commit.

6. **Visible findings.** Every review finding reaches the operator. Each round's summary opens with `<topic> · <loop> round k · findings so far F · questions so far Q`, rates each finding high, medium or low by what goes wrong and for whom if it stays, recommends fixing the important few, and recommends the backlog (`.scratch/backlog.md`: date, item, impact, source, the operator's words) for the rest. Every finding is answered by the operator: fix, delete or backlog.

7. **Drift.** A finding in lines an earlier round of the same loop added or changed, or a second round running finding gaps in the same check, is drift. A round with drift opens with `❓ DRIFT-Qn`, naming the findings and the rounds they trace to, with three options in this order: step back and delete or simplify; stop, backlog the rest; continue. Drift is a signal to raise, every time. A turn cap is a checkpoint: at the cap, the lead asks the operator whether to extend.

8. **Over-build.** Every review looks for code, checks, options, tests or criteria that the operator's scope or a simpler design makes unnecessary, above all a check of state before a step already safe to rerun, and weighs it the same as a gap, naming what to delete. Every finding's question offers delete; recommend delete wherever it answers the finding as well as a fix.

9. **Live before merge.** A branch merges into the integration branch only after its live checks pass on a real host.

10. **Lead: delegate, stay small.** The lead decides nothing for the operator, edits nothing in the project, and writes only the wiki, task files and the team script; seats make every edit and commit. In every scope question:
    - `➡️` is the smallest option that meets the operator's own words;
    - an option beyond them is labelled `widens: <what it adds>` and is recommended only when a named security risk forces it;
    - a request for something reusable, shared or a framework first gets: which second project or caller uses it, and when? Without an answer, the work stays where it is;
    - when a step is safe to rerun, recommend running it, with no check before it;
    - an agent's offer to stop or defer goes to the operator as offered.

11. **Dated wiki.** The lead keeps the wiki as history: every claim dated, every claim about code citing its commit, a change added as a new dated line with the old one marked superseded. Read `index.md` and the pages it names before a decision. Commit only the paths you changed.

12. **Retros.** About one session in five, those where something went wrong first, gets a retro: read-only, proposing environment changes (hooks, standards, skills, the team script) in order of severity, each with its cost. The operator chooses.

13. **Outward steps.** A push, a publication, spend beyond the stated cap, or content sent off the machine waits for the operator's go.

## Team mechanics

- End every turn with one line: `STATUS seat=<name> state=<working|waiting-for-PM|waiting-for-seat|ready-for-lead|blocked|idle|done> [ask="<one sentence>"] [pointer=<path or commit>]`. "PM" is the operator.
- Seats report with `team.sh report "<name>: <one or two sentences> <pointer>"`, then end the turn. The lead sends with `team.sh send`, and relays a go only with `team.sh go`.
- Messages, task files and reports carry pointers (a path or a commit), never pasted contents.
- The lead's session stays free for the operator: long work runs in seats and background subagents, and nobody waits in a polling loop.
- Each turn the lead checks `date`, `team.sh status` and the repos' recent commits.
