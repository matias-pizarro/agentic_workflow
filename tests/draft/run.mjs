#!/usr/bin/env node
// Tests for tools/extensions/draft.ts's text: what /draft <description> becomes
// in the lead's pane (AW-Q72, amended 18 Nov 00:31), and which lines are
// /draft lines. The relay and the lead pane are checked live, in pi panes.
//
// Run: node tests/draft/run.mjs
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const { draftText, draftOf } = await import(pathToFileURL(join(here, "../../tools/extensions/draft.ts")).href);

let failed = 0;
let ran = 0;
const expect = (name, got, want) => {
	ran++;
	if (got !== want) {
		console.log(`FAIL ${name}:\n  got:  ${JSON.stringify(got)}\n  want: ${JSON.stringify(want)}`);
		failed++;
	}
};

const now = new Date(2026, 10, 18, 0, 5);
const rest =
	"\nThe work runs in parallel with the other workflows: it neither blocks them nor is blocked by them. " +
	"It starts by settling the task's perimeter with me using `grill-with-docs`, then proposes how to follow: " +
	"`implement`, `to-spec` + `to-tickets`, a new task on the board, or something else altogether.\n" +
	"Choose at your discretion the seat (a new one or an existing one) and its name, its working directory, " +
	"and its branch and worktree, if any.";

expect("the agreed text", draftText("fixing the login page", now), `[18 Nov 00:05] Task an agent with fixing the login page.${rest}`);
expect("no doubled full stop", draftText("fixing it.", now), `[18 Nov 00:05] Task an agent with fixing it.${rest}`);
expect("quotes kept", draftText(`renaming "foo bar" to 'baz'`, now), `[18 Nov 00:05] Task an agent with renaming "foo bar" to 'baz'.${rest}`);
expect("lines kept", draftText("two things:\n- one\n- two", now), `[18 Nov 00:05] Task an agent with two things:\n- one\n- two.${rest}`);
expect("a /draft line", draftOf(`/draft renaming "foo bar"`), `renaming "foo bar"`);
expect("a bare /draft", draftOf("/draft"), "");
expect("a bare /draft with blanks", draftOf("  /draft   "), "");
expect("/drafts is not /draft", draftOf("/drafts x"), undefined);
expect("text mentioning /draft", draftOf("what does /draft x do?"), undefined);

console.log(failed ? `${failed} of ${ran} cases failed` : `all ${ran} cases passed`);
process.exit(failed ? 1 : 0);
