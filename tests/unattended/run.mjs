#!/usr/bin/env node
// Tests for tools/extensions/unattended.ts's parsing, its order of states
// (ON-Q3–Q5: abort only before the start; start only after a grill; end only
// while open) and the text the lead receives. The lead's pane, the refusal in
// other panes and the tmux option are checked live, in pi panes.
//
// Run: node tests/unattended/run.mjs
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const { parse, next, instruction } = await import(pathToFileURL(join(here, "../../tools/extensions/unattended.ts")).href);

let failed = 0;
let ran = 0;
const expect = (name, got, want) => {
	ran++;
	if (JSON.stringify(got) !== JSON.stringify(want)) {
		console.log(`FAIL ${name}:\n  got:  ${JSON.stringify(got)}\n  want: ${JSON.stringify(want)}`);
		failed++;
	}
};
const refused = (r) => (r && "refused" in r ? "refused" : r);

expect("open with an intent", parse("/unattended-window finish ticket 7"), { command: "open", arg: "finish ticket 7" });
expect("start", parse("  /start-unattended-window  "), { command: "start", arg: "" });
expect("abort", parse("/abort-unattended-window"), { command: "abort", arg: "" });
expect("end", parse("/end-unattended-window"), { command: "end", arg: "" });
expect("a longer name is another command", parse("/unattended-windows x"), undefined);
expect("text mentioning the command", parse("should I /end-unattended-window now?"), undefined);
expect("/stop is not a command here", parse("/stop-unattended-window"), undefined);

expect("open from none", next("", "open", "x"), { state: "grill" });
expect("open with no intent", refused(next("", "open", "")), "refused");
expect("open during a grill", refused(next("grill", "open", "x")), "refused");
expect("open while open", refused(next("open", "open", "x")), "refused");
expect("abort during the grill", next("grill", "abort", ""), { state: "" });
expect("abort after the start", refused(next("open", "abort", "")), "refused");
expect("abort with nothing", refused(next("", "abort", "")), "refused");
expect("start after the grill", next("grill", "start", ""), { state: "open" });
expect("start with no grill", refused(next("", "start", "")), "refused");
expect("start twice", refused(next("open", "start", "")), "refused");
expect("end while open", next("open", "end", ""), { state: "" });
expect("end during the grill", refused(next("grill", "end", "")), "refused");
expect("end with nothing", refused(next("", "end", "")), "refused");
expect("start with text after it", refused(next("grill", "start", "now")), "refused");

const now = new Date(2026, 10, 18, 1, 50);
expect("stamp and intent", instruction("open", "finish ticket 7", now).split("\n")[0], "[18 Nov 01:50] /unattended-window finish ticket 7");
expect("start names the doc", /docs\/unattended-windows\.md/.test(instruction("start", "", now)), true);
expect("end says stop and hold", /stop and hold/.test(instruction("end", "", now)), true);

console.log(failed ? `${failed} of ${ran} cases failed` : `all ${ran} cases passed`);
process.exit(failed ? 1 : 0);
