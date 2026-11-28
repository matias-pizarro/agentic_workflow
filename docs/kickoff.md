# Kickoff: the first hour

A checklist. `<root>` is defined at the top of [index.md](index.md); the why behind each step is there too.

Each step starts with who does it:
- **⌨️ You type:** commands you run, or text you write, yourself.
- **💬 You answer:** you read what the lead shows and reply.
- **⚙️ Automated:** a script or an agent does it; you only watch, or check the result.

In a sandbox session (the sandbox project's tooling), some of your steps are automated; each says which.

## Before the lead starts

1. ⌨️ **Install Pi, its subagents extension, `git` and `tmux`.** `pi install npm:pi-subagents`. ⚙️ In a sandbox session, the template and `sandbox start` have done it. On FreeBSD, the sandbox project's `docs/install-pi.md` lists every step.

2. ⌨️ **Set up the reviewer.** The `review-loop` skill reviews with either the Codex CLI, installed and logged in (`codex login`), or, when `OPENAI_API_KEY` is set, Pi itself on an OpenAI model. Check one of them before the first review: `codex login status`, or `echo $OPENAI_API_KEY`.

3. ⌨️ **Install the skills globally** (⚙️ in a sandbox session, `sandbox start` installs the skills of src's `skills-lock.json` at its first start; check this list against them):
   ```sh
   npx -y skills@latest add mattpocock/skills -g -a pi -y --skill chief-of-staff grill-with-docs grilling to-spec to-tickets implement implement-spec code-review tdd retro writing-for-agents domain-modeling
   npx -y skills@latest add matias-pizarro/agentic_workflow -g -a pi -y --skill review-loop
   npx -y skills@latest add humanlayer/skills -g -a pi -y --skill show-me
   ```
   `show-me` explains the current topic with diagrams, code-shape sketches and focused HTML pages; it runs only when you type `/skill:show-me`. Where it would `open` an HTML file, the agent names its full path instead (rules.md, Team mechanics).
   `grilling` stays installed: `grill-with-docs` and `review-loop` load it. `review-loop` must be from `v1.0.0` or later: earlier versions lack the impact ratings, backlog, drift question and delete option. Check: `grep -c DRIFT ~/.agents/skills/review-loop/SKILL.md` prints a number above 0.

4. ⌨️ **Lay out `<root>`.** Every project gets the same layout and tools, filled with its own content: its own wiki and its own docs tooling, never shared with another project. For a team in a sandbox session, `<root>` is the session's workspace (index.md, `<root>`), laid out the same way; in the sandbox project, ⚙️ `/sandbox/agent-defaults/src/scripts/sandbox-team-root` lays it out, the guards included, and ⌨️ you type that one command, with the repositories' addresses. `src`, `wiki` and `agentic_workflow` are three separate git repositories; `worktrees/` holds linked worktrees of `src`, one per branch, made by seats with `git worktree add`:
   ```
   <root>/
     src/               the project repo
     wiki/              the lead's memory: private, never inside src
     agentic_workflow/  a clone of this repo, at a release tag
     worktrees/         linked worktrees of src
     html/              the pages named to the operator (rules.md, Team mechanics), outside every repo
   ```
   In `<root>`: `git clone --branch v2.23.0 https://github.com/matias-pizarro/agentic_workflow.git`; take a later release with `git -C agentic_workflow checkout <tag>` once its `CHANGELOG.md` section says what it asks. In `<root>/wiki`: `git init`, then give it the commit guard that refuses a file emptied by accident: `ln -s ../../../agentic_workflow/tools/wiki-pre-commit .git/hooks/pre-commit`. The team script runs from `<root>/agentic_workflow/tools/team.sh` and keeps its queue and agent list beside it, git-ignored.

5. ⌨️ **Give `<root>/src` its agent docs**, each short (you write them, or ask the lead for a seat to draft them once it runs):
   - `AGENTS.md`, with this line, `<root>` written out as the real path: `Process rules: <root>/agentic_workflow/docs/rules.md, beside this repo's main checkout. Read them before any ticket, review or question.`;
   - `docs/agents/issue-tracker.md`: tickets as `.scratch/<feature>/issues/NN-<slug>.md`, shaped as [rules.md](rules.md) rule 1 says;
   - `.scratch/backlog.md`: an empty backlog;
   - `CODING_STANDARDS.md`: the judgement rules a reviewer enforces; anything mechanical goes in a hook instead;
   - an ADR for the threat model (every agent assumed compromised) and one for simplicity (no option, layer or generality without a concrete second case).

6. ⌨️ **Install the lead's commit guard:** link it, so it follows each release: `ln -s ../../../agentic_workflow/tools/src-pre-commit <root>/src/.git/hooks/pre-commit`. It refuses any commit made with `TEAM_ROLE=lead`, then runs the hooks the `pre-commit` tool installed, kept as `pre-commit.generated`. With no such hooks, copy it instead, executable, and drop its last line.

   ⌨️ **Install the agents' guards and prompt templates,** a Pi extension refusing tool calls known to go wrong (the README's "Guards" lists them), and `/open-questions`, which makes a seat reprint in its pane every question of yours it still awaits: `cp -n ~/.pi/agent/settings.json ~/.pi/agent/settings.json.bak-guards`, then `node <root>/agentic_workflow/tools/extensions/install.mjs`. Rerun the second after taking a new release.

   In a sandbox session, where the project's sandbox tooling provides it, ⚙️ `sandbox start` runs `install.mjs` itself at every start, from the sandbox host's read-only copy of agentic_workflow at the release the tooling names (in the sandbox project, `lib/agentic_workflow.sh` and `/sandbox/agent-defaults/agentic_workflow`): skip this step there. A new release reaches the sandboxes once the tooling's release moves and the host's setup reruns, so Methodology names each release for that move, and the session's `<root>/agentic_workflow` takes the same tag.

7. ⌨️ **Be ready to spawn an expendable environment**: a disposable container or jail, a test VM or a cloud sandbox, plus a spending cap you are comfortable with. The first ticket runs there.

## Start the lead

8. ⌨️ In a tmux window:
   ```sh
   cd <root>/wiki && TEAM_ROLE=lead pi
   ```
   then, in that pane's shell or with `!` in Pi: `tmux set -p @role lead`.

9. ⌨️ Type, with `<root>` written out:
   ```
   /skill:chief-of-staff
   Goal: <one paragraph, in your words>.
   Follow <root>/agentic_workflow/docs/rules.md. The wiki is <root>/wiki; the project is <root>/src; the team script is <root>/agentic_workflow/tools/team.sh. Every task file names the rules by that absolute path.
   Start the wiki (index.md, goal.md), then ask me the sizing question for the first piece of work.
   ```

## The first exchange

10. ⚙️ **Check the wiki start.** The lead writes it; you read it. `goal.md` holds your goal with a date; `index.md` lists it.

11. 💬 **Answer the first sizing question.** It quotes your words, says what each tier would build and recommends the lowest. An option labelled `widens:` adds something you did not ask for. Pick consciously.

12. 💬 **Name the seats.** Tell the lead the project's builder areas, a name for each (one lowercase, expressive word: GLOSSARY.md, "Seat name"), and which of them stay always on (rules.md rule 16). ⚙️ The lead spawns the coordinators, `architect`, `coach`, `librarian` and `heimdall`, and the always-on builders first; the other builders roll on when their area gets work.

13. ⚙️ **Watch the first seat spawn.** Its task file's first line is `Ceremony: <tier> (the operator, "<your words>", <date> hh:mm)`. `team.sh status` shows its `STATUS` line.

14. 💬 **Answer in the format.** `yes`, `no`, your own words, `ok` (trust without full understanding) or `why?`, by ID. A go typed in a seat's pane counts.

## Signs it is working

- The first ticket ran live on the expendable host before any review.
- Every summary opens with its running-cost line.
- Questions arrive one ID each, with a `➡️` you can accept with `yes`.

## Signs to stop and ask `why?`

- A recommendation bigger than what you asked for, with no `widens:` label.
- A request of yours to make something reusable turned into a framework, with no question about who else uses it.
- Round after round of findings in code the previous round wrote, with no `❓ DRIFT` question.
- A test or check standing in for a live run, with no question asking your approval.
