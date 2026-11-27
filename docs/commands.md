# Commands, prompt templates and extensions

What `node tools/extensions/install.mjs` puts in pi, and the commands you type in a pane. Read from the code at integration `54852b7` (18 Nov 2026). The README lists the commands in one line each and links here.

## Commands and tools

| Command | Where | Provided by | What it does |
|---|---|---|---|
| `/open-questions`, `/o` | any pane | `open-questions.md`; `/o` by `open-questions.ts` | prints the seat's unanswered questions and prefills the answer rows |
| `/draft <description>` | the lead's pane; elsewhere relayed to the lead | `draft.ts` (listed by `draft.md`) | asks the lead to task an agent, with the grilling first |
| `/unattended-window <intent>` | the lead's pane | `unattended.ts` (listed by its template) | opens an unattended window's grill ([unattended-windows.md](unattended-windows.md)) |
| `/abort-unattended-window` | the lead's pane | `unattended.ts` (listed by its template) | drops the grill before the start |
| `/start-unattended-window` | the lead's pane | `unattended.ts` (listed by its template) | starts the window |
| `/end-unattended-window` | the lead's pane | `unattended.ts` (listed by its template) | ends the window |
| `/refresh <seat>…`, `all`, `lead`, then optionally `--min <percent>` | the lead's pane; refused elsewhere | `refresh.ts` (listed by `refresh.md`) | hands each seat to a new session in its pane through a handoff (`team.sh refresh`); reports to the lead per seat |
| `/beep-from all\|<seat>`, `/mute all\|<seat>` | any pane | `beep.ts` (listed by `beep-from.md`, `mute.md`) | turns the audible signal on or off for the whole team or one seat (a tmux window's name); muted by default and after a tmux restart; no turn starts |
| `/reload-runtime` | any pane | `open-questions.ts` | the same as pi's `/reload`, which you use; it exists because the `reload_runtime` tool can send only a command an extension registers |
| `reload_runtime` (a tool, not typed) | any seat | `open-questions.ts` | the seat reloads itself, on the lead's or your word |

## Extensions

From `tools/extensions/`, installed into `~/.pi/agent/extensions/`.

| Extension | Loaded by | What it does |
|---|---|---|
| `guards.ts` | every session and subagent | sibling-guard, heredoc-guard, and the time stamp on each typed message |
| `open-questions.ts` | the main session | `/o`; question colours and the answer prefill; the tab's colour, `[n]` and ⚡; question-ID registration; the `reload_runtime` tool and `/reload-runtime` |
| `draft.ts` | the main session | `/draft` |
| `unattended.ts` | the main session | the four unattended-window commands |
| `ledger.ts` | the main session | appends each session's start and stop to the ledger, `tools/ledger`; sets the pane's `@session-id` and `@session-name`, which `team.sh refresh` reads |
| `refresh.ts` | the main session | `/refresh` |
| `beep.ts` | the main session | `/beep-from`, `/mute`; plays `beep` three times at the end of a turn that asks a new question or newly enters `waiting-for-PM`, unless the seat is muted; marks a turn that ends aborted or in error as blocked, its tab red, with a signal |

## Prompt templates

From `tools/prompts/`, installed into `~/.pi/agent/prompts/`.

| Template | What it is for |
|---|---|
| `open-questions.md` | `/open-questions`: the seat prints its unanswered questions |
| `draft.md` | lists `/draft` in autocomplete; its text runs only when `draft.ts` is not loaded, and asks for `/reload` |
| `unattended-window.md`, `abort-unattended-window.md`, `start-unattended-window.md`, `end-unattended-window.md` | list the four unattended-window commands in autocomplete; same fallback, with `unattended.ts` |
| `refresh.md` | lists `/refresh` in autocomplete; same fallback, with `refresh.ts` |
| `beep-from.md`, `mute.md` | list `/beep-from` and `/mute` in autocomplete; same fallback, with `beep.ts` |

Not installed: `tools/handoff.md`, the template a seat follows when `team.sh refresh` asks it for its handoff.

After an install, `/reload` each pane it lists.
