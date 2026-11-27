## Review of `integration...5c87ccb`

1. **Medium impact for the lead and Docs, low effort** · `tools/merge-ready:83` skips a removed hostname if a different hostname still contains it as a prefix. `git grep -wF` treats a dot as a word boundary, so `api.example.com.backup` can suppress a warning for `api.example.com`. Match complete hostname and address tokens in both source and docs searches.
2. **Medium impact for Docs, low effort** · `tools/merge-ready:92–107` splits `docs/Run Book.md` into two filenames, and `awk` would still truncate it after fixing the loop. Preserve each path through collection and grouping. Add a test covering a Markdown filename with spaces in both the committed tree and an external docs directory.
3. **Medium impact for the lead, very low effort** · `tools/merge-ready:96–99` makes the advisory scan refuse a merge when an external directory is missing or unreadable. A missing directory only triggers the refusal when a candidate token survives. Delete the refusal and the test that requires it. Diagnose incomplete coverage while retaining the readiness result.
4. **Medium impact for the lead and Docs, low effort** · `tools/merge-ready:77–79` emits `no-ff` from a command option and accepts `999.999.1.2`, while missing `node-a` and dropping a deleted source line beginning `--`. Parse deletion lines within hunks and tighten token extraction. The approved research also includes ports and interface names, so a port-only change such as the reported port 80 closure can bypass the merge-time Docs check. Cover those facts or record the narrower gate as a scope decision.
5. **Low impact for the lead on large diffs, medium effort** · `tools/merge-ready:81–99` runs up to two Git searches and one recursive search per external directory for every token. Batch the patterns and scan each tree once, especially before enabling this across repositories.
6. **Low impact for adopters, very low effort** · `docs/index.md:115` omits the Docs condition from its Rule 9 summary, and `CHANGELOG.md:7` has no entry for the new lead, Architecture, and Docs duties. Add the condition to the summary and document the duties in the next release entry using the existing `**Act:**` convention.

Rule 16 assigns the push and weekly read to the requested seats. FreeBSD `sh` preserved spaces when splitting the colon-separated directory list, and Git emitted the expected commit prefix. The `|| rc=$?` guards capture search statuses under `set -e`. The extraction pipeline’s `|| true` also suppresses real extraction failures, so an incomplete scan can appear clean.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Reviewed the fixed diff against the brief and approved research, with six line-specific findings and residual verification risks."
    }
  ],
  "changedFiles": [],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "git diff integration...5c87ccb; git show a9100a8:.scratch/coach/doc-freshness.md",
      "result": "passed",
      "summary": "Inspected the implementation, tests, rule changes, and approved research."
    },
    {
      "command": "git diff --check integration...5c87ccb; sh -n on each changed shell script",
      "result": "passed",
      "summary": "Whitespace and syntax checks passed on FreeBSD."
    },
    {
      "command": "Read-only Git pathspec, token extraction, and FreeBSD sh IFS probes",
      "result": "passed",
      "summary": "Confirmed commit-prefixed Git output, exclusions, token examples, and space preservation during directory splitting."
    },
    {
      "command": "git grep --no-index -wF -e api.example.com -- /dev/stdin",
      "result": "failed",
      "summary": "Git rejected stdin outside the repository. The dotted-prefix finding is based on word-boundary semantics."
    },
    {
      "command": "tests/merge-ready; .scratch/coach/cron-live.sh",
      "result": "not-run",
      "summary": "Both create state and the review was read-only."
    }
  ],
  "validationOutput": [
    "FreeBSD, Git 2.56.0. No staged paths."
  ],
  "residualRisks": [
    "The lead-owned wiki cron entry and actual delivery were not verified.",
    "Large-diff runtime was not benchmarked."
  ],
  "noStagedFiles": true,
  "diffSummary": "The reviewed branch adds an advisory freshness scan, a test fixture, a cron probe, and Rules 9 and 16 changes.",
  "reviewFindings": [
    "medium: tools/merge-ready:83 - punctuation boundaries can suppress a stale hostname",
    "medium: tools/merge-ready:92 - filenames with spaces are corrupted",
    "medium: tools/merge-ready:96 - advisory scan failures change readiness",
    "medium: tools/merge-ready:77 - extraction is noisy and misses approved fact types",
    "low: tools/merge-ready:81 - repeated scans scale with the token count",
    "low: docs/index.md:115 and CHANGELOG.md:7 - adoption guidance is incomplete"
  ],
  "manualNotes": "Read-only review. The complete artifact is returned here for runtime persistence to the requested .scratch/coach/review.md path."
}
```