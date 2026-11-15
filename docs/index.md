# Playbook: running a project with a team of Pi agents

This is how to run software work with a team of [Pi](https://github.com/earendil-works/pi) agents, one lead and several workers, with you deciding everything that matters. It keeps what worked on a multi-day project and guards against what went wrong there. Reading it takes about 20 minutes.

**`<root>`** in all paths here is the directory holding the project's three repositories side by side: `<root>/src` (the project), `<root>/wiki` (the lead's memory) and `<root>/agentic_workflow` (a clone of this repo, at a release tag), plus `<root>/worktrees` for the project's branch worktrees.

The repo holds:

- **`docs/index.md`** (this page): what the process is, who does what, and why each rule exists.
- **[kickoff.md](kickoff.md)**: a checklist for your first hour.
- **[rules.md](rules.md)**: the rules, worded for agents. Point every agent at it.
- **`tools/team.sh`**: the team script; **`tools/src-pre-commit`**: the lead's commit guard; **`tools/wiki-pre-commit`**: the wiki's, refusing a file emptied by accident; **`tools/merge-ready`**: the check before a branch merges (rule 9).
- **`skills/`**: the skills this process adds to the ones it installs from elsewhere, such as `review-loop`.
- **`CHANGELOG.md`**: what each release changed, and what a project must do to take it.

## What the process is

You give a goal. A long-running Pi session, the **lead**, holds it and turns it into work. Each piece of work goes to an agent of its own, a **seat**, which writes the code, runs it for real on a machine you can afford to lose, gets an independent review, and brings every question back to you through the lead. The lead keeps a dated record of every decision in a **wiki**, a git repository of markdown pages. That record lets a restarted lead, or the next project, pick up where things stood.

It produces good work when three things hold:

1. **You size the work before it starts.** Each ticket gets a ceremony tier: a checklist, a plain script, or full engineering. The tier is your call, made on the lead's question.
2. **Reality checks the work before reviewers do.** Every ticket first runs for real on an expendable host. The review comes after.
3. **Everything stays visible.** Every review finding, every running cost and every sign of drift reaches you. Nothing is hidden to save you time.

It goes wrong in one recognisable way: work grows past what you asked for, one reasonable-sounding "yes" at a time. On the project this playbook comes from, "a script to install Pi" became two tickets and 22 review rounds, with 1,700 lines in the first ticket alone. What was wanted was 15 commands typed by hand. The scope grew through the lead's recommendations, which the operator accepted 53 times out of 53. Most of the rules below exist to stop that.

## The roles

| Role | Who | Owns | Never |
|---|---|---|---|
| **Operator** | you | the goal, every tier, every scope and spend decision, every review finding's answer, anything outward-facing (a push, a publication, money) | is asked for a fact an agent could look up |
| **Lead** | one Pi session running the `chief-of-staff` skill, its working directory in the wiki | the wiki and task files; asking you questions, relaying answers, recording decisions | edits project files or commits in the project repo; grows scope |
| **Seat** | one Pi session per workflow, in its own tmux window, started by the lead | every edit and commit for its task, its review loop, its report | decides for you; claims a choice of its own was yours |
| **Worker** | a subagent a seat starts (with `pi-subagents`), e.g. one implementer per ticket in its own git worktree | one ticket or one investigation | outlives its task |
| **Reviewer** | a different model from the writer's (e.g. GPT reviewing Claude's code), started by the `review-loop` or `code-review` skill | a findings report | edits files |

Why a lead who edits nothing: when the lead fixes things by hand, nobody reviews them and its context fills with detail it needs for deciding. A commit guard enforces it (see [kickoff.md](kickoff.md)).

Why a separate reviewer model: a second model has different blind spots, and reading a diff with no exploration to do is cheap.

## How work flows

1. **Goal.** You state it; the lead records it, dated, in the wiki's `goal.md`.
2. **Sizing.** For each piece of work the lead asks `❓ CS-Q1 – Size <work> as <tier>?`, quoting your words and saying what each tier would build. It recommends the lowest tier your words allow. You answer.
3. **Task file.** The lead writes a short task file whose first line records your choice, `Ceremony: script (the operator, "yes", 14 Nov 09:57)`. The team script refuses a task file without that line. The lead then starts a seat on it.
4. **Plan, if the work is big.** The seat runs `grill-with-docs` with you to settle the design, then `to-spec` and `to-tickets`, which write a spec and one ticket file per slice, each with its blocking tickets. Small work skips this.
5. **Build and run.** The seat builds (`implement` for one ticket; `implement-spec` for a spec, with one worker per ticket in parallel) and runs it live on an expendable host, by trial and error, until it works.
6. **Review**, as the tier says: none, one pass, or the review loop. Each round's summary comes to you through the lead.
7. **Merge.** The seat merges the integration branch into its own and resolves any conflict there, and code changed since its last live run runs live again; then the branch merges into the integration branch. Pushing waits for your go.
8. **Record.** The lead adds dated lines to the wiki: what you decided, with your words and the time.
9. **Retro.** About one session in five, an agent reviews what happened and proposes changes to the environment. You choose which to adopt.

### The ceremony tiers

| Tier | Use it for | What gets built | Review |
|---|---|---|---|
| `checklist` | something run once or rarely, by a person watching, where each failure shows on screen and the step can be rerun | a doc page of numbered commands, one line each on what it does | none |
| `script` | the same, but run often or by an agent, and nothing a misbehaving agent could exploit | a plain script running the steps in order, relying on each step being safe to rerun | one review pass; the loop only on your words |
| `full` | code an agent can reach or trigger, that runs as root for agents, or that spends money or holds credentials unattended | acceptance criteria, a table of what a failure at each step leaves, reads of system state that say yes, no or failed | the review loop |
| `none` | research, retros, write-ups: no code | the document | as you choose |

A `checklist` or `script` ticket says in one sentence what a failure leaves and what to do ("nothing harmful; rerun" is common); a `full` ticket carries the step-by-step failure table instead. Adopting code that already works, by moving it, generalising it or putting it under review, is a ticket of its own with its own tier. Expect to tune the tiers as you learn.

### Reading a review summary

Every round's summary opens with its running cost:

```
install-pi · code round 4 · findings so far 9 · questions so far 7
```

Then, when it applies, a drift question comes first (see rule 7). Then each finding, rated for impact (high, medium or low, by what goes wrong and for whom if it stays) and for effort (very low to high). Each finding offers three answers: **fix**, **delete** (remove the code the finding sits in) or **backlog** (park it in the project's `.scratch/backlog.md`). The summary recommends fixing the few findings that carry most of the harm, and fixing now any minor one that costs a word or a line; only minor findings with real effort are recommended for the backlog. You can overrule any of it.

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

## The rules, and why

[rules.md](rules.md) is the one full statement of the rules, numbered as here. This list gives each rule's reason.

0. **The rules override broader skill defaults.** *Why: the installed skills were written for other teams; some fix every finding, run reviews regardless of tier, or act on retro proposals without asking.*
1. **You choose each ticket's ceremony tier, before it is written.** *Why: left alone, the full ceremony becomes everyone's habit, and a 15-command job gets two tickets and 22 review rounds.*
2. **Live run first, on an expendable host; no fakes where a live test is practical.** *Why: on install-pi the first real run found, in minutes, the one gap six review rounds had missed; and a test against invented tool output passed a check that then rejected a working host.*
3. **Every sandbox and agent is assumed compromised.** *Why: agents did run host commands by accident (a shell heredoc slip ran lines of a file as root commands; none took effect); damage stays small only where the environment is built for it.*
4. **Questions carry unique IDs and a recommendation; `ok` is recorded as trust.** *Why: unique IDs let you answer ten questions in one line without ambiguity; recording `ok` apart from `yes` keeps your informed decisions from being confused with your trust.*
5. **A deliberate choice carries your words and the time; a claimed edit names its commit.** *Why: agents have called their own shortcuts "deliberate choices" and claimed edits they never made; a quote with a time, and a commit that touches the file, can be checked by a hook or by you.*
6. **Every review finding reaches you, rated by impact and effort; a cheap fix is made now, a costly minor one goes to the backlog.** *Why: applying small fixes silently would hide the problem rather than solve it; rating by impact lets you stop fixing everything without losing sight of anything, and rating effort keeps one-line fixes out of the backlog, where recording them costs more than making them.*
7. **A long review loop is a drift signal to pick up, never capped by tier.** *Why: a loop finding a gap in the previous round's fix, four rounds running, has lost its way; capping it would hide that, flagging it lets you act.*
8. **Over-build is a finding; "delete it" is always offered.** *Why: reviews that hunt only for gaps only ever add code; on install-pi, 22 rounds produced one deletion, and the next round added the check back.*
9. **Live checks pass before any merge.** *Why: a converged review loop says nothing about whether code runs; install-pi's converged loop failed its first real run at the package step.*
10. **The lead delegates every edit and never inflates scope (the `widens:` label).** *Why: you will answer most questions with `yes`, so the lead's recommendation is in practice the decision; the lead must recommend small and label the rest.*
11. **The wiki is dated history.** *Why: the lead's context is lost at compaction, at a restart, or when a new lead takes over; the wiki is what survives, and undated claims rot without anyone noticing.*
12. **Retros on about one session in five.** *Why: most of these rules came out of retros; without them the same failure recurs with a new name.*
13. **Outward-facing steps wait for your go.** *Why: a push, a publication or money spent cannot be taken back.*
14. **A change to a check, not the code, is flagged loudly and asked; a new check must first fail on the broken code.** *Why: changing a check to make it pass is the easiest way to hide a real failure, and a weakened check silently weakens everything resting on it.*

## Keeping the team running

The lead starts seats and passes messages with `<root>/agentic_workflow/tools/team.sh` (`spawn`, `send`, `go`, `report`, `status`, `revive --all` after a tmux restart, `doctor` after a host reboot; run it without arguments for the list). `doctor` checks the host settings and mounts the agents depend on, listed one per line in `tools/expect` beside the script (its format is in `team.sh`'s header), and prints one block of fixes for you to run on the host. Messages wait until the receiving pane's input box is empty, so a report never lands in your half-typed sentence. Every agent turn ends with a `STATUS` line, so the lead knows who needs what without polling; `waiting-for-PM` means waiting for you. After each Pi upgrade, run `team.sh selftest`: a Pi interface change can otherwise leave every message stuck.

## Changing this playbook

The same way the rules were made: a retro proposes, you decide, and the files state only the rules as they now stand. Each change ships in a release, a `vX.Y.Z` tag; `CHANGELOG.md` says what each one asks of a project.
