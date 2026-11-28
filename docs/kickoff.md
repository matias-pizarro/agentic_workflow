# Kickoff: the first hour

A checklist. `<root>` is defined at the top of [index.md](index.md); the why behind each step is there too.

A team runs on your own host or in a sandbox session; each step shows both, side by side. Who does it:
- **⌨️ You type:** commands you run, or text you write, yourself.
- **💬 You answer:** you read what the lead shows and reply.
- **⚙️ Automated:** a script or an agent does it; you only watch, or check the result.

The sandbox column is the sandbox project's tooling (`sandbox`, in its `docs/install-sandbox.md`), with a sandbox host already set up; another project's sandbox tooling may differ.

## Before the lead starts

Each step side by side, its commands in the rows under it, one per row.

| Step | On your own host | In a sandbox session |
|---|---|---|
| **0. Enter** | ⌨️ Open a shell on the host. | ⌨️ Once per project, on the sandbox host, create the project and register each deploy key it prints on the forge: |
| | | `sandbox project create <project> --repo <src remote> --repo <wiki remote>` |
| | | Then each time; it opens tmux in the workspace, which is `<root>`: |
| | | `sandbox start -p <project> -s <session>` |
| **1. Pi, its packages, `git`, `tmux`** | ⌨️ Install them; on FreeBSD, the sandbox project's `docs/install-pi.md` lists every step. Pi's subagents: | ⚙️ Done by the `agents` template and `sandbox start`. |
| | `pi install npm:pi-subagents` | |
| **2. Logins and the reviewer** | ⌨️ Claude's login for pi. For reviews, the Codex CLI logged in, or `OPENAI_API_KEY` set: | ⌨️ Once, on the host, in `/agents/users/<user>/credentials/env`: |
| | `codex login` | `CLAUDE_CODE_OAUTH_TOKEN=…` |
| | Check one of them: | Then in the sandbox, and `/login` inside pi, openai-codex: |
| | `codex login status` | `codex login --device-auth` |
| | `echo $OPENAI_API_KEY` | |
| **3. Skills** | ⌨️ Install them: | ⚙️ Done at the first `sandbox start`, from src's `skills-lock.json`; check it lists the same skills. |
| | `npx -y skills@latest add mattpocock/skills -g -a pi -y --skill chief-of-staff grill-with-docs grilling to-spec to-tickets implement implement-spec code-review tdd retro writing-for-agents domain-modeling` | |
| | `npx -y skills@latest add matias-pizarro/agentic_workflow -g -a pi -y --skill review-loop` | |
| | `npx -y skills@latest add humanlayer/skills -g -a pi -y --skill show-me` | |
| | Check `review-loop` is v1.0.0 or later; this prints a number above 0: | |
| | `grep -c DRIFT ~/.agents/skills/review-loop/SKILL.md` | |
| **4. Lay out `<root>`** | ⌨️ By hand, in `<root>`, with `src` cloned or made there: | ⌨️ One command, in `<root>`, as the sandbox's user. ⚙️ It makes the layout below and links both commit guards (steps 4 and 6): |
| | `git clone --branch v2.23.0 https://github.com/matias-pizarro/agentic_workflow.git` | `/sandbox/agent-defaults/src/scripts/sandbox-team-root <src remote> <wiki remote>` |
| | `mkdir worktrees html` | |
| | `git init wiki` (or a clone of the wiki's private remote) | |
| | The wiki's commit guard, refusing a file emptied by accident: | |
| | `ln -s ../../../agentic_workflow/tools/wiki-pre-commit wiki/.git/hooks/pre-commit` | |
| | A later release, once its `CHANGELOG.md` section says what it asks: | |
| | `git -C agentic_workflow checkout <tag>` | |
| **5. src's agent docs** | ⌨️ Write them (list below), or have a seat draft them once the lead runs. | ⌨️ The same. |
| **6. The lead's commit guard** | ⌨️ Link it; with no hooks from the `pre-commit` tool, copy it instead, executable, and drop its last line: | ⚙️ Done in step 4. |
| | `ln -s ../../../agentic_workflow/tools/src-pre-commit <root>/src/.git/hooks/pre-commit` | |
| **6. The agents' guards and prompt templates** | ⌨️ Install them; rerun the second after each new release: | ⚙️ Done at every `sandbox start`, from the host's copy at the release the tooling names (`lib/agentic_workflow.sh`); a new release arrives once that tag moves and `sandbox host setup` reruns. |
| | `cp -n ~/.pi/agent/settings.json ~/.pi/agent/settings.json.bak-guards` | |
| | `node <root>/agentic_workflow/tools/extensions/install.mjs` | |
| **7. An expendable environment** | ⌨️ Have one ready (a disposable container or jail, a test VM, a cloud sandbox) and a spending cap you are comfortable with. The first ticket runs there. | ⌨️ The same; seats test in a child jail or a cloud sandbox, not in the session itself. |

**The layout (step 4).** Every project gets the same layout and tools, filled with its own content: its own wiki and its own docs tooling, never shared with another project. `src`, `wiki` and `agentic_workflow` are three separate git repositories; `worktrees/` holds linked worktrees of `src`, one per branch, made by seats with `git worktree add`:
```
<root>/
  src/               the project repo
  wiki/              the lead's memory: private, never inside src
  agentic_workflow/  a clone of this repo, at a release tag
  worktrees/         linked worktrees of src
  html/              the pages named to the operator (rules.md, Team mechanics), outside every repo
```
The team script runs from `<root>/agentic_workflow/tools/team.sh` and keeps its queue and agent list beside it, git-ignored.

**The skills (step 3).** `show-me` explains the current topic with diagrams, code-shape sketches and focused HTML pages; it runs only when you type `/skill:show-me`. Where it would `open` an HTML file, the agent names its full path instead (rules.md, Team mechanics). `grilling` stays installed: `grill-with-docs` and `review-loop` load it. `review-loop` before v1.0.0 lacks the impact ratings, backlog, drift question and delete option.

**The agent docs (step 5),** each short:
- `AGENTS.md`, with this line, `<root>` written out as the real path: `Process rules: <root>/agentic_workflow/docs/rules.md, beside this repo's main checkout. Read them before any ticket, review or question.`;
- `docs/agents/issue-tracker.md`: tickets as `.scratch/<feature>/issues/NN-<slug>.md`, shaped as [rules.md](rules.md) rule 1 says;
- `.scratch/backlog.md`: an empty backlog;
- `CODING_STANDARDS.md`: the judgement rules a reviewer enforces; anything mechanical goes in a hook instead;
- an ADR for the threat model (every agent assumed compromised) and one for simplicity (no option, layer or generality without a concrete second case).

**The guards (step 6).** The lead's commit guard refuses any commit made with `TEAM_ROLE=lead`, then runs the hooks the `pre-commit` tool installed, kept as `pre-commit.generated`. The agents' guards are a Pi extension refusing tool calls known to go wrong (the README's "Guards" lists them) and `/open-questions`, which makes a seat reprint in its pane every question of yours it still awaits.

## Start the lead

The same on a host and in a sandbox session, in a tmux window in `<root>/wiki`.

8. ⌨️ Start it:
   ```sh
   cd <root>/wiki && TEAM_ROLE=lead pi
   ```
   then, in that pane's shell, or after `!` in Pi:
   ```sh
   tmux set -p @role lead
   ```

9. ⌨️ Type, with `<root>` written out:
   ```
   /skill:chief-of-staff
   Goal: <one paragraph, in your words>.
   Follow <root>/agentic_workflow/docs/rules.md. The wiki is <root>/wiki; the project is <root>/src; the team script is <root>/agentic_workflow/tools/team.sh. Every task file names the rules by that absolute path.
   Start the wiki (index.md, goal.md), then ask me the sizing question for the first piece of work.
   ```

## The first exchange

The same on a host and in a sandbox session, but for what rules.md's Team mechanics says of pages and the signal in a sandbox.

10. ⚙️ **Check the wiki start.** The lead writes it; you read it: `goal.md` holds your goal with a date; `index.md` lists it.

11. 💬 **Answer the first sizing question.** It quotes your words, says what each tier would build and recommends the lowest. An option labelled `widens:` adds something you did not ask for. Pick consciously.

12. 💬 **Name the seats.** Tell the lead the project's builder areas, a name for each (one lowercase, expressive word: GLOSSARY.md, "Seat name"), and which of them stay always on (rules.md rule 16). ⚙️ The lead spawns the coordinators, `architect`, `coach`, `librarian` and `heimdall`, and the always-on builders first; the other builders roll on when their area gets work.

13. ⚙️ **Watch the first seat spawn.** Its task file's first line is `Ceremony: <tier> (the operator, "<your words>", <date> hh:mm)`. This shows its `STATUS` line:
    ```sh
    <root>/agentic_workflow/tools/team.sh status
    ```

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
