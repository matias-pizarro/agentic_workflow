---
description: Drop an unattended window's grill before its start, in the lead's pane (handled by unattended.ts; this template lists it)
---
The operator typed `/abort-unattended-window`, but the extension unattended.ts did not handle it, so it is not loaded in this pane. Do nothing about any unattended window: tell the operator to run /reload (after `node tools/extensions/install.mjs` in agentic_workflow if unattended.ts is missing from ~/.pi/agent/extensions), then type it again.
