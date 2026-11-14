# Kickoff: the first hour

A checklist. The why behind each step is in [README.md](README.md).

## Before the lead starts

1. **Install Pi with subagents and a second model for reviews.** Pi itself, `pi install npm:pi-subagents`, and a reviewer model from another vendor than the writer's (e.g. `pi install npm:pi-gpt` with `codex login`, or Pi's `/login`). On FreeBSD, follow the sandbox project's `docs/install-pi.md`; it includes the heredoc guard extension. Also needed: `git`, `tmux`.

2. **Install the skills globally**:
   ```sh
   npx -y skills@latest add mattpocock/skills -g -a pi -y --skill chief-of-staff grilling to-spec to-tickets implement implement-spec code-review tdd retro writing-for-agents domain-modeling
   npx -y skills@latest add matias-pizarro/skills -g -a pi -y --skill review-loop
   ```
   Check: `ls ~/.agents/skills`.

3. **Lay out the directories** side by side, each its own git repository:
   ```
   <project>/
     src/        the project repo
     wiki/       the lead's memory: private, never inside src
     playbook/   a clone of this repo, shared across projects
     worktrees/  one per branch, created by seats
   ```
   In `wiki/`: `git init`, a `tools/` directory, and a copy of `team.sh` from an existing wiki's `tools/` (e.g. the sandbox project's `wiki/tools/team.sh`).

4. **Give `src` its agent docs**, each short:
   - `AGENTS.md`, with this line: `Process rules: ../playbook/RULES.md. Read them before any ticket, review or question.`;
   - `docs/agents/issue-tracker.md`: tickets as `.scratch/<feature>/issues/NN-<slug>.md`, each with a `**Ceremony:**` line and an `**If it fails:**` line; the tier table from README.md;
   - `.scratch/backlog.md`: an empty backlog, one dated entry per parked item;
   - `CODING_STANDARDS.md`: the judgement rules a reviewer enforces; anything mechanical goes in a hook instead;
   - an ADR for the threat model (every agent assumed compromised) and one for simplicity (no option, layer or generality without a concrete second case).

5. **Install the lead's commit guard** in `src/.git/hooks/pre-commit`: refuse any commit when `TEAM_ROLE=lead`, else run the usual hooks (e.g. the sandbox project's `wiki/tools/src-pre-commit`).

6. **Have an expendable host ready**: a disposable container or jail, a test VM or a cloud sandbox, plus a spending cap you are comfortable with. The first ticket runs there.

## Start the lead

7. In a tmux window:
   ```sh
   cd <project>/wiki && TEAM_ROLE=lead pi
   ```
   then, in that pane's shell or with `!` in Pi: `tmux set -p @role lead`.

8. Type:
   ```
   /skill:chief-of-staff
   Goal: <one paragraph, in your words>.
   Follow ../playbook/RULES.md. The wiki is this directory; the project is ../src.
   Start the wiki (index.md, goal.md), then ask me the sizing question for the first piece of work.
   ```

## The first exchange

9. **Check the wiki start.** `goal.md` holds your goal with a date; `index.md` lists it.

10. **Answer the first sizing question.** It quotes your words, says what each tier would build and recommends the lowest. If an option is labelled `widens:`, it adds something you did not ask for. Pick consciously.

11. **Watch the first seat spawn.** Its task file's first line is `Ceremony: <tier> (the operator, "<your words>", <date> hh:mm)`. `tools/team.sh status` shows its `STATUS` line.

12. **Answer in the format.** `yes`, `no`, your own words, `ok` (trust without full understanding) or `why?`, by ID. A go typed in a seat's pane counts.

## Signs it is working

- The first ticket ran live on the expendable host before any review.
- Every summary opens with its running-cost line.
- Questions arrive one ID each, with a `➡️` you can accept with `yes`.

## Signs to stop and ask `why?`

- A recommendation bigger than what you asked for, with no `widens:` label.
- A request of yours to make something reusable turned into a framework, with no question about who else uses it.
- Round after round of findings in code the previous round wrote, with no `❓ DRIFT` question.
- A test or check standing in for a live run, with no question asking your approval.
