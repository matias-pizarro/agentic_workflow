# Playbook: running a project with a team of Pi agents

This is how to run software work with a team of [Pi](https://github.com/earendil-works/pi) agents, one lead and several workers, with you deciding everything that matters. It keeps what worked on a multi-day project and guards against what went wrong there. Reading it takes about 20 minutes.

Three files:

- **README.md** (this file): what the process is, who does what, how to start it, and the rules with their reasons.
- **[KICKOFF.md](KICKOFF.md)**: a checklist for your first hour.
- **[RULES.md](RULES.md)**: the same rules as a terse list. Point every agent at it.

## What the process is

You give a goal. A long-running Pi session, the **lead**, holds it and turns it into work. Each piece of work goes to an agent of its own, a **seat**, which writes the code, runs it for real on a machine you can afford to lose, gets an independent review, and brings every question back to you through the lead. The lead keeps a dated record of every decision in a **wiki**, a git repository of markdown pages. That record lets a restarted lead, or the next project, pick up where things stood.

It produces good work when three things hold:

1. **You size the work before it starts.** Each ticket gets a ceremony tier: a checklist, a plain script, or full engineering. The tier is your call, made on the lead's question.
2. **Reality checks the work before reviewers do.** Every ticket first runs for real on an expendable host. The review comes after.
3. **Everything stays visible.** Every review finding, every running cost and every sign of drift reaches you. Nothing is hidden to save you time.

It goes wrong in one recognisable way: work grows past what you asked for, one reasonable-sounding "yes" at a time. On the project this playbook comes from, "a script to install Pi" became two tickets, about 1,700 lines and 22 review rounds. What was wanted was 15 commands typed by hand. The scope grew through the lead's recommendations, which the operator accepted 53 times out of 53. Most of the rules below exist to stop that.

## The roles

| Role | Who | Owns | Never |
|---|---|---|---|
| **Operator** | you | the goal, every tier, every scope and spend decision, every review finding's answer, anything outward-facing (a push, a publication, money) | is asked for a fact an agent could look up |
| **Lead** | one Pi session running the `chief-of-staff` skill, its working directory in the wiki | the wiki, task files, the team script; asking you questions, relaying answers, recording decisions | edits project files or commits in the project repo; grows scope |
| **Seat** | one Pi session per piece of work, in its own tmux window, started by the lead | every edit and commit for its task, its review loop, its report | decides for you; claims a choice of its own was yours |
| **Worker** | a subagent a seat starts (with `pi-subagents`), e.g. one implementer per ticket in its own git worktree | one ticket or one investigation | outlives its task |
| **Reviewer** | a different model from the writer's (e.g. GPT reviewing Claude's code), started by the `review-loop` or `code-review` skill | a findings report | edits files |

Why a lead who edits nothing: when the lead fixes things by hand, nobody reviews them and its context fills with detail it needs for deciding. A commit guard enforces it (see KICKOFF.md).

Why a separate reviewer model: a second model has different blind spots, and reading a diff with no exploration to do is cheap.

## How work flows

1. **Goal.** You state it; the lead records it, dated, in the wiki's `goal.md`.
2. **Sizing.** For each piece of work the lead asks `❓ CS-Q1 – Size <work> as <tier>?`, quoting your words and saying what each tier would build. It recommends the lowest tier your words allow. You answer.
3. **Task file.** The lead writes a short task file whose first line records your choice, `Ceremony: script (the operator, "yes", 14 Nov 09:57)`. The team script refuses a task file without that line. The lead then starts a seat on it.
4. **Plan, if the work is big.** The seat runs `grilling` with you to settle the design, then `to-spec` and `to-tickets`, which write a spec and one ticket file per slice, each with its blocking tickets. Small work skips this.
5. **Build and run.** The seat builds (`implement` for one ticket; `implement-spec` for a spec, with one worker per ticket in parallel) and runs it live on an expendable host, by trial and error, until it works.
6. **Review**, as the tier says: none, one pass, or the review loop. Each round's summary comes to you through the lead.
7. **Merge.** Live checks pass, then the branch merges into the integration branch. Pushing waits for your go.
8. **Record.** The lead adds dated lines to the wiki: what you decided, with your words and the time.
9. **Retro.** About one session in five, an agent reviews what happened and proposes changes to the environment. You choose which to adopt.

### The ceremony tiers

| Tier | Use it for | What gets built | Review |
|---|---|---|---|
| `checklist` | something run once or rarely, by a person watching, where each failure shows on screen and the step can be rerun | a doc page of numbered commands, one line each on what it does | none |
| `script` | the same, but run often or by an agent, and nothing a misbehaving agent could exploit | a plain script running the steps in order, relying on each step being safe to rerun | one review pass |
| `full` | code an agent can reach or trigger, that runs as root for agents, or that spends money or holds credentials unattended | acceptance criteria, a table of what a failure at each step leaves, careful reads of system state | the review loop |
| `none` | research, retros, write-ups: no code | the document | as you choose |

Every ticket says in one sentence what a failure leaves and what to do ("nothing harmful; rerun" is common). Only `full` tickets carry the step-by-step failure table. Adopting code that already works, by moving it, generalising it or putting it under review, is a ticket of its own with its own tier. Expect to tune the tiers as you learn.

### Reading a review summary

Every round's summary opens with its running cost:

```
install-pi · code round 4 · findings so far 9 · questions so far 7
```

Then, when it applies, a drift question comes first (see rule 7). Then each finding, rated high, medium or low by what goes wrong and for whom if it stays. Each finding offers three answers: **fix**, **delete** (remove the code the finding sits in) or **backlog** (park it in the project's `.scratch/backlog.md`). The summary recommends fixing only the few findings that carry most of the harm; the rest are recommended for the backlog. You can overrule any of it.

## How to answer

Every question looks like this:

```
❓ CS-Q3 – Size the vnet cut as full?
It runs as root on agents' behalf (threat model); script would skip the failure table.
➡️ Yes: full, live runs only, review loop.
```

- **`yes`** accepts the recommendation (`➡️`). `yes to all` accepts every open one.
- **`no`**, or your own words, rejects or changes it. Answers in your own words are the ones that steer.
- **`ok`** means "I trust you on this because it sounds reasonable, but I lack a full understanding of the question." The lead records it as such and re-explains it before anything hard to reverse is built on it.
- **`why?`** is always a valid answer. Asking it has repeatedly turned up a recommendation the lead could not defend.
- Answer several at once by ID: `CS-Q3: yes, RT-Q2: no, keep both`.

You may type into any agent's pane. A go given there counts; the agent quotes your words and the time to the lead.

## The rules

The rules as they stand, each with the reason it exists. [RULES.md](RULES.md) carries the same rules, numbered the same, worded for agents.

1. **You choose each ticket's ceremony tier, before it is written.** The lead asks and recommends the lowest tier your words allow; a higher tier names its reason. *Why: left alone, the full ceremony becomes everyone's habit, and a 15-command job gets 1,700 lines and 22 review rounds.*

2. **Live run first, on an expendable host.** Every ticket's work is verified by running it for real on a host you can lose: a disposable container or jail, a test VM, a cloud sandbox. Work by trial and error there, and throw the host away after. Nothing that replaces a practical live test with a fixture, a fake or a dry run gets built. When a live run is impractical, that exception is its own question to you. *Why: on install-pi the first real run found, in minutes, the one gap six review rounds had missed; and a test against invented tool output passed a check that then rejected a working host.*

3. **Every sandbox and agent is assumed compromised.** Design as if any agent may, by error or by intent, do the worst its environment allows. Containment comes from disposable environments and isolation (an agent's tests run in a child container it can wreck), not from trusting the agent or nursing the host. Expose only what is expendable. *Why: agents did run host commands by accident (a shell heredoc slip ran lines of a file as root commands; none took effect); damage stays small only where the environment is built for it.*

4. **Questions carry unique IDs and a recommendation.** The format is the `❓ ID – question?` / `➡️ answer` block above, worded so `yes` accepts it. An ID is never reused (a prefix per thread: `CS-Q1`, `RT-Q2`). `ok` is recorded as trust without full understanding and re-explained before anything hard to reverse follows from it. *Why: unique IDs let you answer ten questions in one line without ambiguity; recording `ok` apart from `yes` keeps your informed decisions from being confused with your trust.*

5. **A deliberate choice carries your words and the time.** When you accept a risk or a cost, the ticket or response records it as "Deliberate choice", quoting you: `(the operator, "keep it", 13 Nov 17:28)`. A seat relaying your go quotes it the same way. An agent's own choice goes to review instead. *Why: agents have called their own shortcuts "deliberate choices" and claimed edits they never made; a quote with a time can be checked, by a hook or by you.*

6. **Every review finding reaches you, rated by impact.** Each summary opens with the loop's running cost, rates each finding high, medium or low, recommends fixing the important few, and offers the backlog for the rest. The backlog is a visible file; nothing is fixed or dropped unasked. *Why: applying small fixes silently would hide the problem rather than solve it; rating by impact lets you stop fixing everything without losing sight of anything.*

7. **A long review loop is a drift signal; pick it up.** When a round's findings sit in code an earlier round of the same loop added, or two rounds running find gaps in the same check, the summary opens with `❓ DRIFT-Qn`: step back and delete or simplify; stop and send the rest to the backlog; or continue. No tier caps a loop; a turn cap only means the lead asks you whether to extend. *Why: a loop finding a gap in the previous round's fix, four rounds running, has lost its way; capping it would hide that, flagging it lets you act.*

8. **Over-build is a finding; "delete it" is always offered.** Every review looks for code, checks, options, tests or criteria that your scope or a simpler design makes unnecessary, above all a check before a step that is already safe to rerun, and weighs it like a gap. Every finding's question offers deletion. *Why: reviews that hunt only for gaps only ever add code; on install-pi, 22 rounds produced one deletion, and the next round added the check back.*

9. **Live checks pass before any merge.** No branch merges into the integration branch until its live checks pass on a real host. *Why: a converged review loop says nothing about whether code runs; install-pi's converged loop failed its first real run at the package step.*

10. **The lead delegates every edit and never inflates scope.** Seats make every edit and commit; a hook refuses the lead's commits in the project repo. On scope:
    - the recommended answer is the smallest option that meets your own words;
    - an option beyond them is labelled `widens: <what it adds>` and is not the one recommended, unless a named security risk forces it;
    - a request to make something reusable, shared or a framework gets one question first: which second project or caller uses it, and when; with no answer, the work stays where it is;
    - when a question's own text shows a step is safe to rerun, the recommendation is to run it, with no check before it;
    - an agent's offer to stop or defer goes to you as offered.

    *Why: you will answer most questions with `yes`, so the lead's recommendation is in practice the decision; the lead must recommend small and label the rest.*

11. **The wiki is dated history.** Every claim in it carries a date, and a claim about code carries the commit it was true at. A change adds a new dated line and marks the old one superseded; nothing is rewritten. The lead reads it before deciding. *Why: the lead's context is lost at compaction, at a restart, or when a new lead takes over; the wiki is what survives, and undated claims rot without anyone noticing.*

12. **Retros on about one session in five.** Pick the sessions where something went wrong. A retro agent reads the session logs, reviews and wiki, changes nothing, and proposes changes to the environment (hooks, standards, skills, the team script) in order of severity, each with its cost. You choose. *Why: most of the rules above came out of retros; without them the same failure recurs with a new name.*

13. **Outward-facing steps wait for your go.** Pushing, publishing, spending beyond a stated cap, and anything that sends content off the machine. *Why: these cannot be taken back.*

## Things that keep the team running

- **The team script.** `team.sh spawn <name> <cwd> <task file>` opens a seat in a new tmux window with its own Pi session; `report` sends a seat's message to the lead; `send` and `go` send the lead's; `status` lists every seat's last `STATUS` line; `revive --all` reopens every seat in its saved session after a tmux restart. Messages queue until the receiving pane's input box is empty, so a report never lands in a half-typed sentence.
- **The status line.** Every agent turn ends with one line, `STATUS seat=<name> state=<working|waiting-for-PM|waiting-for-seat|ready-for-lead|blocked|idle|done>`, so the lead knows who needs what without polling. "PM" here is you.
- **Pointers, not pastes.** Messages, task files and reports name a path or a commit; they never paste contents.
- **Files are written with the editor tools, never through a shell heredoc.** A quoting slip in a heredoc runs the rest of the file as shell commands. A Pi extension, the heredoc guard, refuses the dangerous form.
- **The lead's session is never held by long work.** Everything long runs in seats or background subagents, so you can always talk to the lead.

## Where this came from

These rules came from two retrospectives and the operator's answers to them, on a FreeBSD sandboxing project run this way over several days in November 2026. Its project repo carries working examples: `AGENTS.md`, `CODING_STANDARDS.md`, `docs/agents/issue-tracker.md` (the tiers and ticket shape) and `docs/install-pi.md` (installing Pi on FreeBSD). Change this playbook the same way: a retro proposes, you decide, and the playbook states only the rules as they now stand.
