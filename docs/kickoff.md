# Kickoff: the first hour

A checklist. `<root>` is defined at the top of [README.md](README.md); the why behind each step is there too.

## Before the lead starts

1. **Install Pi, its subagents extension, `git` and `tmux`.** `pi install npm:pi-subagents`. On FreeBSD, the sandbox project's `docs/install-pi.md` lists every step.

2. **Set up the reviewer.** The `review-loop` skill reviews with either the Codex CLI, installed and logged in (`codex login`), or, when `OPENAI_API_KEY` is set, Pi itself on an OpenAI model. Check one of them before the first review: `codex login status`, or `echo $OPENAI_API_KEY`.

3. **Install the skills globally**:
   ```sh
   npx -y skills@latest add mattpocock/skills -g -a pi -y --skill chief-of-staff grilling to-spec to-tickets implement implement-spec code-review tdd retro writing-for-agents domain-modeling
   npx -y skills@latest add matias-pizarro/skills -g -a pi -y --skill review-loop
   ```
   `review-loop` must be at `matias-pizarro/skills` commit `ec04983` or later: earlier versions lack the impact ratings, backlog, drift question and delete option. Check: `grep -c DRIFT ~/.agents/skills/review-loop/SKILL.md` prints a number above 0.

4. **Lay out `<root>`.** `src`, `wiki` and `playbook` are three separate git repositories; `worktrees/` holds linked worktrees of `src`, one per branch, made by seats with `git worktree add`:
   ```
   <root>/
     src/        the project repo
     wiki/       the lead's memory: private, never inside src
     playbook/   a clone of this repo
     worktrees/  linked worktrees of src
   ```
   In `<root>/wiki`: `git init`. The team script runs from `<root>/playbook/tools/team.sh` and keeps its queue and agent list beside it, git-ignored.

5. **Give `<root>/src` its agent docs**, each short:
   - `AGENTS.md`, with this line, `<root>` written out as the real path: `Process rules: <root>/playbook/RULES.md, beside this repo's main checkout. Read them before any ticket, review or question.`;
   - `docs/agents/issue-tracker.md`: tickets as `.scratch/<feature>/issues/NN-<slug>.md`, shaped as [RULES.md](RULES.md) rule 1 says;
   - `.scratch/backlog.md`: an empty backlog;
   - `CODING_STANDARDS.md`: the judgement rules a reviewer enforces; anything mechanical goes in a hook instead;
   - an ADR for the threat model (every agent assumed compromised) and one for simplicity (no option, layer or generality without a concrete second case).

6. **Install the lead's commit guard:** copy `<root>/playbook/tools/src-pre-commit` to `<root>/src/.git/hooks/pre-commit`, executable. It refuses any commit made with `TEAM_ROLE=lead`, then runs the hooks the `pre-commit` tool installed, kept as `pre-commit.generated` (with none, drop its last line).

7. **Be ready to spawn an expendable environment**: a disposable container or jail, a test VM or a cloud sandbox, plus a spending cap you are comfortable with. The first ticket runs there.

## Start the lead

8. In a tmux window:
   ```sh
   cd <root>/wiki && TEAM_ROLE=lead pi
   ```
   then, in that pane's shell or with `!` in Pi: `tmux set -p @role lead`.

9. Type, with `<root>` written out:
   ```
   /skill:chief-of-staff
   Goal: <one paragraph, in your words>.
   Follow <root>/playbook/RULES.md. The wiki is <root>/wiki; the project is <root>/src; the team script is <root>/playbook/tools/team.sh. Every task file names the rules by that absolute path.
   Start the wiki (index.md, goal.md), then ask me the sizing question for the first piece of work.
   ```

## The first exchange

10. **Check the wiki start.** `goal.md` holds your goal with a date; `index.md` lists it.

11. **Answer the first sizing question.** It quotes your words, says what each tier would build and recommends the lowest. An option labelled `widens:` adds something you did not ask for. Pick consciously.

12. **Watch the first seat spawn.** Its task file's first line is `Ceremony: <tier> (the operator, "<your words>", <date> hh:mm)`. `team.sh status` shows its `STATUS` line.

13. **Answer in the format.** `yes`, `no`, your own words, `ok` (trust without full understanding) or `why?`, by ID. A go typed in a seat's pane counts.

## Signs it is working

- The first ticket ran live on the expendable host before any review.
- Every summary opens with its running-cost line.
- Questions arrive one ID each, with a `➡️` you can accept with `yes`.

## Signs to stop and ask `why?`

- A recommendation bigger than what you asked for, with no `widens:` label.
- A request of yours to make something reusable turned into a framework, with no question about who else uses it.
- Round after round of findings in code the previous round wrote, with no `❓ DRIFT` question.
- A test or check standing in for a live run, with no question asking your approval.
