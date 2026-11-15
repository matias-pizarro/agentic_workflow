#!/usr/bin/env node
// Tests for tools/extensions/guards.ts, its handlers driven as pi drives them.
//
// sibling/: each file is a real pi session (pi 1.5.2, `pi -p -e guards.ts`,
// claude-bridge, 15 Nov 2026, in /tmp/guards-live-*), cut after the assistant
// message that holds the bash call, which is the session's state at that call's
// tool_call; the system-prompt entry is dropped. Every call of that message is
// driven: a bash call must be refused (refused-*) or let through (allowed-*),
// any other call let through.
//
// Run: node tests/guards/run.mjs
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const handlers = [];
const pi = { on: (event, handler) => event === "tool_call" && handlers.push(handler) };
(await import(pathToFileURL(join(here, "../../tools/extensions/guards.ts")).href)).default(pi);

// The first block, as pi takes it, or undefined.
async function verdict(event, ctx) {
	for (const handler of handlers) {
		const result = await handler(event, ctx);
		if (result?.block) return result.reason;
	}
	return undefined;
}

let failed = 0;
let ran = 0;
const fail = (name, why) => {
	console.log(`FAIL ${name}: ${why}`);
	failed++;
};

for (const name of readdirSync(join(here, "sibling"))) {
	const entries = readFileSync(join(here, "sibling", name), "utf8")
		.trim()
		.split("\n")
		.map((line) => JSON.parse(line))
		.filter((entry) => entry.type !== "session");
	const ctx = { sessionManager: { getBranch: () => entries } };
	const message = entries.findLast((entry) => entry.type === "message" && entry.message.role === "assistant").message;
	for (const call of message.content.filter((part) => part.type === "toolCall")) {
		ran++;
		const event = { type: "tool_call", toolCallId: call.id, toolName: call.name, input: call.arguments };
		const reason = await verdict(event, ctx);
		const refuse = call.name === "bash" && name.startsWith("refused-");
		if (refuse && !reason?.startsWith("sibling-guard: refused.")) fail(`${name} ${call.name}`, "let through, expected refused");
		if (refuse && !reason?.includes("Run the command in your next message")) fail(`${name} ${call.name}`, `the reason does not say to run it in the next message: ${reason}`);
		if (!refuse && reason !== undefined) fail(`${name} ${call.name}`, `refused, expected let through: ${reason}`);
	}
}

if (ran === 0) fail("sibling", "no cases");
console.log(failed ? `${failed} of ${ran} calls failed` : `all ${ran} calls passed`);
process.exit(failed ? 1 : 0);
