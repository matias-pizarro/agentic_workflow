**Three findings in `integration...62b4b15`.**

| Location | Impact | Finding and fix |
|---|---|---|
| `tools/board.mjs:606–607, :633` | Medium for the operator. Small fix for window identity, moderate effort for layout repair. | The code treats any window named `board` as the destination and any bot pane in a window with that name as correctly placed. A second `board` can receive the bot or suppress the move, and a mispositioned bot in the real board stays mispositioned. Resolve the board at index 0 to a stable window ID, use that ID throughout, and check the pane’s geometry before skipping placement. |
| `tools/team.sh:1596–1600` | Low for the lead diagnosing revive. Small fix. | A failed join returns 1 after the board may already have opened. Revive says the board was not reopened and returns the seats’ status, which can be 0. Keep the documented seats-only exit status, make the warning cover board setup, and update the revive help at line 38 to mention bot placement. `docs/index.md:126` describes when to run revive and makes no conflicting layout claim. |
| `.scratch/coach/board-bot-live.sh:8–11, :18–31` | Low for maintainers running the check. Small deletion. | The script prints results without asserting them, masks revive’s status behind `sed`, and kills a fixed socket name before setup. Delete the one-off script from the diff and retain the observed results in the task record. Also trim the duplicate geometry and operator prose at `tools/board.mjs:590–593`. |

The session-wide pane scan covers a tagged bot in either the lead or a seat window. A successful `join-pane -d -v -f -l 4` creates a full-width bottom split. If the join runs first, `both` later splits only its own pane horizontally, above the bot. The missing-role path reports the skip and exits 0. The supplied live results were reviewed without rerunning the state-changing script. This response is the artifact for `.scratch/coach/review.md` in the read-only run.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "One static pass over the requested diff found three issues with source locations, impact, effort, and fixes."
    }
  ],
  "changedFiles": [],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "git diff integration...62b4b15",
      "result": "passed",
      "summary": "Reviewed the board implementation, live-check script, and task record."
    },
    {
      "command": "git diff --check integration...62b4b15",
      "result": "passed",
      "summary": "No whitespace errors."
    },
    {
      "command": "git diff --cached --name-only",
      "result": "passed",
      "summary": "No staged files."
    }
  ],
  "validationOutput": [
    "Traced pane discovery and join, both startup orders, already-open behavior, and revive exit handling."
  ],
  "residualRisks": [
    "The reported live runs did not independently verify duplicate board names, mispositioned panes, or a split failure in a constrained terminal.",
    "Bot startup and role assignment are outside this diff. If the role appears after open scans the session, placement waits for another open."
  ],
  "noStagedFiles": true,
  "diffSummary": "Adds phone-bot placement to board open and adds a manual live-check script and task record.",
  "reviewFindings": [
    "medium: tools/board.mjs:606 - Window name and pane presence are insufficient to validate placement.",
    "low: tools/team.sh:1599 - Join failure produces a misleading revive diagnostic.",
    "low: .scratch/coach/board-bot-live.sh:8 - One-off script has a fixed socket and no assertions."
  ],
  "manualNotes": "Read-only review. Live observations came from the task brief. No files were edited."
}
```