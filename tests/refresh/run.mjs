#!/usr/bin/env node
// Tests for the pure parts of tools/extensions/ledger.ts and refresh.ts
// (ticket .scratch/refresh/issues/01-refresh.md; seams agreed in RF-Q14): the
// ledger's line, which pi session events it logs, and which typed lines are
// /refresh lines. pi's real events, tmux and team.sh are checked by team.sh
// selftest and the live run.
//
// Run: node tests/refresh/run.mjs
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const ext = (name) => import(pathToFileURL(join(here, "../../tools/extensions", name)).href);
const { ledgerLine, logged } = await ext("ledger.ts");
const { refreshOf, source } = await ext("refresh.ts");

let failed = 0;
let ran = 0;
const expect = (name, got, want) => {
	ran++;
	if (JSON.stringify(got) !== JSON.stringify(want)) {
		console.log(`FAIL ${name}:\n  got:  ${JSON.stringify(got)}\n  want: ${JSON.stringify(want)}`);
		failed++;
	}
};

const at = new Date(2026, 10, 18, 1, 5, 9);
expect(
	"a ledger line: time, event, seat, session id, session name, detail, tab-separated",
	ledgerLine("start", "prod-net", "6a6d72ad-e26e", "prod-net 2026-11-18 01:05", "startup", at, "CET"),
	"2026-11-18 01:05:09 CET\tstart\tprod-net\t6a6d72ad-e26e\tprod-net 2026-11-18 01:05\tstartup\n",
);
expect(
	"an unnamed session logs an empty name",
	ledgerLine("stop", "lead", "abc", undefined, "quit", at, "CET"),
	"2026-11-18 01:05:09 CET\tstop\tlead\tabc\t\tquit\n",
);
expect(
	"tabs and newlines in a field cannot split the line",
	ledgerLine("start", "a\tb", "id", "two\nlines", "x\ty", at, "CET"),
	"2026-11-18 01:05:09 CET\tstart\ta b\tid\ttwo lines\tx y\n",
);
for (const reason of ["startup", "new", "resume", "fork", "quit"]) expect(`pi's ${reason} is logged`, logged(reason), true);
expect("pi's reload is not a start or stop", logged("reload"), false);

expect("one seat", refreshOf("/refresh prod-net"), ["prod-net"]);
expect("several seats", refreshOf("  /refresh a1  b.2 c_3 "), ["a1", "b.2", "c_3"]);
expect("all", refreshOf("/refresh all"), ["all"]);
expect("the lead", refreshOf("/refresh lead"), ["lead"]);
expect("a bare /refresh", refreshOf("/refresh"), []);
expect("/refreshed is not /refresh", refreshOf("/refreshed x"), undefined);
expect("text mentioning /refresh", refreshOf("what does /refresh x do?"), undefined);
expect("a name team.sh would refuse is passed on for it to refuse", refreshOf("/refresh a;b"), ["a;b"]);
expect("where and when: the lead pane and the typed time", source(at), "lead pane 01:05");

console.log(failed ? `${failed} of ${ran} cases failed` : `all ${ran} cases passed`);
process.exit(failed ? 1 : 0);
