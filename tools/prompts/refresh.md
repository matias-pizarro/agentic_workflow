---
description: In the lead's pane, hand seats to new sessions through a handoff (handled by refresh.ts; this template lists it)
argument-hint: "<seat>… | all | lead"
---
The operator typed `/refresh $@`, but the extension refresh.ts did not handle it, so it is not loaded in this pane. Do nothing with the request: tell the operator to run /reload (after `node tools/extensions/install.mjs` in agentic_workflow if refresh.ts is missing from ~/.pi/agent/extensions), then type it again.
