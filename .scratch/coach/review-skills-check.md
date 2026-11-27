**Four findings. The daily prompt is missing from the inspected wiki, and the cached Skills CLI already provides `check -g`.**

| Location | Finding and impact | Effort and fix |
|---|---|---|
| `docs/rules.md:88` | **High, lead.** The rule says the wiki crontab prompts the lead daily. The inspected wiki `crontab` contains only the weekly lint job. `.scratch/coach/cron-live.sh:17` exercises message delivery with a hardcoded prompt, so it cannot verify the scheduled entry. | Small. Add the daily `team.sh send lead` entry in the wiki and verify the actual command. |
| `tools/skills-check:5`, `docs/index.md:16` | **Medium, maintainers.** The script duplicates `skills check -g`, implemented in cached versions 1.8.1 and 1.9.1 through the updater’s report-only path. | Small. Delete `tools/skills-check`, remove its index entry, and use `npx skills check -g` in the rule and prompt. Delete the one-off cron harness and task brief after recording the live evidence. |
| `tools/skills-check:20`, `tools/skills-check:35` | **Medium, lead.** The comparison matches GitHub’s tree-backed hash for a skill at an unchanged nested path on the queried ref. Root `SKILL.md` produces `HEAD:.`, which FreeBSD Git failed to resolve. The script also ignores `ref` and `sourceType`. The CLI honors refs, can rediscover moved skills by name, checks for missing installed copies, and uses different checks for non-GitHub sources. A subpath alone works when the recorded `skillPath` is repo-relative and still valid. | Small via deletion. If retained, scope the helper to supported GitHub entries, handle root trees and refs, and surface unsupported entries separately from updates. |
| `tools/skills-check:25`, `tools/skills-check:36` | **Low, lead.** Unquoted URL enumeration splits whitespace and expands globs. A valid local source path with spaces can fail before comparison. A failed tree lookup is also counted as “behind,” so the documented read-error status covers clone failures but misses lookup failures. | Small via deletion. If retained, read source records literally and distinguish missing paths from Git read errors. |

On FreeBSD, the heredoc loop preserved counters across source iterations. A clone failure sets a sticky status of `2`, even if another source reports updates. The rule preserves operator approval, reloads after changed updates, and keeps reladraw out of scope.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Four findings include file and line, impact, effort, and a fix or deletion. FreeBSD shell behavior, CLI parity, and residual verification gaps are recorded."
    }
  ],
  "changedFiles": [],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "git diff integration...9f6db80 && git diff --check integration...9f6db80",
      "result": "passed",
      "summary": "Reviewed all four changed files. Diff whitespace check passed."
    },
    {
      "command": "sh -n tools/skills-check && sh -n .scratch/coach/cron-live.sh",
      "result": "passed",
      "summary": "Both scripts parsed on FreeBSD."
    },
    {
      "command": "FreeBSD sh heredoc counter probe and git rev-parse tree-selector probe",
      "result": "passed",
      "summary": "Counter reached two across source iterations. HEAD: and HEAD^{tree} resolved; HEAD:. did not."
    },
    {
      "command": "Inspect cached Skills CLI, wiki crontab, global lock source types, and Git index",
      "result": "passed",
      "summary": "CLI implements check mode. Wiki crontab has only weekly lint. All 43 current lock entries are GitHub. Index is empty."
    }
  ],
  "validationOutput": [
    "FreeBSD heredoc count=2",
    "HEAD:. unresolved; HEAD: and HEAD^{tree} resolve to the same tree",
    "43 GitHub lock entries",
    "Wiki crontab has one active weekly lint entry"
  ],
  "residualRisks": [
    "The supplied live clone and cron harness results were not rerun in read-only mode.",
    "The loaded host crontab and live delivery were not independently verified.",
    "The native CLI can print a source failure without counting it as an update failure, so its exit status is not equivalent to the wrapper's status 2."
  ],
  "noStagedFiles": true,
  "diffSummary": "Adds a global skill checker, a cron delivery harness and task brief, and updates Team mechanics and the docs index.",
  "reviewFindings": [
    "high: docs/rules.md:88 - Inspected wiki crontab lacks the daily prompt.",
    "medium: tools/skills-check:5 - Native CLI check mode makes the wrapper redundant.",
    "medium: tools/skills-check:20 - Hash and source resolution diverge from CLI behavior for root paths, refs, moves, missing installations, and other source types.",
    "low: tools/skills-check:25 - URL splitting and tree lookup error handling can misreport results."
  ],
  "manualNotes": "Read-only review of the pinned diff. Reviewed cached CLI code without executing it. The complete report is returned in the response for runtime persistence to .scratch/coach/review.md."
}
```