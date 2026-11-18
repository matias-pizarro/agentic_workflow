# Backlog

Parked items: date, item, impact, source, the operator's words.

- 18 Nov 2026 · Stale-lock takeover race in `team.sh`: two callers that both find a dead owner's lock (`refresh_lock`, and the same pattern in `lock()`, used by the deliverer and the registry) can each remove it and take it, so both run. Needs two refreshes of one seat, or two deliverers of one target, at the instant a dead owner's lock is found. · Impact low: two runs at once on one seat or queue, at a rare instant. · Source: [refresh review 1a, finding 2](refresh/reviews/review-codex-202611180738-f49e4ed-findings.md) · The operator, "yes" to RF-Q18, 18 Nov 07:53.
