Ceremony: docs (the operator, "yes to all", 27 Nov 2026 00:58)

# Task: the playbook for a team in a sandbox session (SH-Q81 rule part, SH-Q82, SH-Q84 wording)

Seat: coach. Branch: `docs/sandbox-team` in agentic_workflow (`/agents/sessions/freebsd/sandbox/skills`), from `integration` 6a6f796. One ticket, one branch (CS-Q96 (a), the operator, "yes to all", relayed by the lead 27 Nov 00:58).

**Start:** after sandbox-host's task 199 merges; the lead says when. Until then, nothing but this file.

## Source

Vikunja task 200, research by sandbox-host: `/agents/sessions/freebsd/sandbox/worktrees/docs/team-in-sandbox/.scratch/sandbox-host/team-in-sandbox.md`, sections "What the methodology is, as installed things" and "Decisions for the user"; the methodology part taken over in `/agents/sessions/freebsd/sandbox/skills/.scratch/agentic-workflow/principles-review-methodology.md`.

## What it changes

1. **SH-Q81, the rule part.** `docs/rules.md`, Team mechanics: the pages named to the operator (`<root>/html/`, md-html, mermaid.html) and the beep, where the team runs in a sandbox session the operator's browser and speaker cannot reach. The rule says what must hold (the operator can open every page named, and hears the signal); the mechanism (the mount, rclone or sshfs) is sandbox-host's and is named, not specified.
2. **SH-Q82, `<root>` in a sandbox session.** `docs/index.md` (the definition of `<root>`) and `docs/kickoff.md` step 4 (laying out `<root>`). Where the workspace sits inside a sandbox session comes from sandbox-host; ask it before writing.
3. **SH-Q84, the wording.** `docs/kickoff.md` step 6: in a sandbox session, `install.mjs` runs at every start from `<root>/agentic_workflow`, the team's own clone at its release tag, which coach moves to each new release. Same words as task 199's.

Out of scope: SH-Q86 (CS-Q95 (a): this team stays on the host; a new project's team proves the sandbox install later, a checklist ticket after tasks 197 to 199); the mount itself; SH-Q83 (Security's), SH-Q85 (the Lead's).

## Checks

- Live check: no docs build in agentic_workflow; `tools/md-html` renders each changed page, named to the operator.
- **If it fails:** the playbook still describes only a team on the host, and the sandbox bring-up uses sandbox-host's own wording until this lands.
- Review: the operator reads the diff (rule 1, `docs`).
- Release: a patch or minor release with an **Act** line for seats if a rule changes; the release is its own step.
