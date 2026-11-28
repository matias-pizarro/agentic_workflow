The background fix is supported by the recorded live run. The old run logged child start and stop events under `seatx` and left the child’s ID in `@session-id`. The new run recorded a child with `PI_SUBAGENT_CHILD=1`, logged only the seat’s start, and retained the seat’s ID. `.scratch/coach/subagent-live-old.log:1–10`, `.scratch/coach/subagent-live-new.log:1–10`.

- **Medium · Foreground opt-in bypass · Medium effort.** `tools/extensions/ledger.ts:73` and the three matching guards miss explicitly configured local foreground children. The installed runner hosts those children in the parent process without setting the marker. It disables ambient extension discovery, so the standard install is covered, but explicitly loading one of these extensions into a foreground child can bring back the pane or ledger writes for that seat. Enforce the exclusion in child extension selection or use session-scoped child metadata. Update the four comments to describe the actual launch behavior. Installed bundle `chunk-XAOHLFJO.js:1354–1382,5442`.
- **Low · Inherited marker disables seat extensions · Small effort.** `tools/team.sh:378,383,675,679` leaves an inherited marker intact. A real seat started with `PI_SUBAGENT_CHILD=1` silently loses all four extensions, including the hook refresh waits on to publish `@session-id`. Clear the marker at intentional seat launch boundaries.
- **Low · Live script can give false confidence · Small effort.** `.scratch/coach/subagent-live.sh:28–38` waits a fixed time and prints diagnostics. It can exit successfully if the child never ran or the pane ID is wrong. Keep the captured logs and add exit-status assertions for child completion, ledger ownership, and pane ID.

Native chain and worktree steps follow their foreground or background host. The background runner sets the marker before loading Pi children. External CLIs bypass Pi extension loading. Generic external commands inherit the runner environment by default, while adapter allowlists can omit the marker. A wrapper that starts Pi falls outside that guarantee. Installed package `src/runs/background/subagent-runner.js:92,696,3982`, `src/runs/shared/external-cli-runner.js:46–63`.

`open-questions.ts:379–459` intentionally drops `reload_runtime`, markdown styling, automatic md-html page generation, and question registration in children. Those are seat functions under this request. `install.mjs:6–11` and `README.md:59,68–70` agree with that intent. The four one-line guards are proportionate.

I reviewed the saved live evidence in one read-only pass and returned the artifact here for runtime persistence to `.scratch/coach/review-subagent-quiet.md`.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Reviewed the requested commit range, traced launch paths in the installed package, and checked the recorded old/new live results. Findings and residual risks are listed."
    }
  ],
  "changedFiles": [],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "git diff integration...6b91032",
      "result": "passed",
      "summary": "Reviewed four early returns and the live-check artifacts."
    },
    {
      "command": "git diff --check integration...6b91032",
      "result": "failed",
      "summary": "Three captured ledger rows end in a tab for an empty name field."
    },
    {
      "command": "sh -n .scratch/coach/subagent-live.sh",
      "result": "passed",
      "summary": "Shell syntax is valid."
    },
    {
      "command": "git diff --cached --quiet",
      "result": "passed",
      "summary": "No staged changes."
    },
    {
      "command": ".scratch/coach/subagent-live.sh <extension directory>",
      "result": "not-run",
      "summary": "Read-only review used the recorded old/new runs."
    }
  ],
  "validationOutput": [
    "Old trace contains child ledger writes and the child pane ID. New trace contains a marked child, a seat-only ledger, and the seat pane ID.",
    "Bundle inspection confirms local foreground sessions share the parent process and disable ambient extension discovery."
  ],
  "residualRisks": [
    "Explicitly selected foreground extensions can bypass the marker guard.",
    "A real seat launched with an inherited marker silently disables all four extensions.",
    "An external wrapper that launches Pi can lack the marker after adapter environment filtering.",
    "Only the recorded background case has live evidence."
  ],
  "noStagedFiles": true,
  "diffSummary": "Adds four early-return guards and a task note, live harness, debug extension, and captured traces.",
  "reviewFindings": [
    "medium: tools/extensions/ledger.ts:73 - Explicit foreground extension loading bypasses the process marker.",
    "low: tools/team.sh:378 - Seat launch preserves an inherited child marker.",
    "low: .scratch/coach/subagent-live.sh:28 - Script reports diagnostics without asserting success."
  ],
  "manualNotes": "Read-only one-pass review. Cross-checked the cited postmaster ledger rows, the installed runner and source, the installer defaults, the README, and the captured live traces. Returned the artifact in this response for runtime persistence."
}
```