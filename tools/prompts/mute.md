---
description: Mute the audible signal for the whole team or one seat (handled by beep.ts; this template lists it)
argument-hint: "all | <seat>"
---
The operator typed `/mute $@`, but the extension beep.ts did not handle it, so it is not loaded in this pane. Do nothing with the request: tell the operator to run /reload (after `node tools/extensions/install.mjs` in agentic_workflow if beep.ts is missing from ~/.pi/agent/extensions), then type it again.
