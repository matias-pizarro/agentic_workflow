# Glossary

**Seat**: a named, long-lived role on the team (e.g. `prod-net`), held by one agent session at a time in one tmux window of that name.

**Coordinator**: a seat that keeps one dimension consistent across the team and holds its single source of truth: the Lead, Architecture, Methodology, Docs or Security. Always deployed.

**Builder**: a seat that designs, builds and maintains one area of components, named by the project. Always deployed if the project says so; otherwise it rolls on and off on demand.

**Roll on, roll off**: starting a builder seat when its area has work, from a task file naming its last check-out and its components' READMEs; retiring it, with its check-out written and those READMEs current, when it has none. While it is off, the Lead triages incidents on its components.

**Session**: one pi conversation, identified by its session id and, optionally, its session name. A seat is held by a succession of sessions.

**Registry**: the record of each seat's current session: its working directory, task file and session id. It is overwritten as a seat changes session.

**Ledger**: the history of every session start and stop and every refresh event, each with its seat, session id and session name. It is only ever appended to.

**Refresh**: handing a seat from its current session to a new one in the same tmux pane, through a handoff, at the operator's request.

**Handoff**: the document an outgoing session writes so that the next session holding the seat can take over its work.
