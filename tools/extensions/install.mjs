#!/usr/bin/env node
// Install the guards for this user's pi: copy guards.ts into
// ~/.pi/agent/extensions/, which every pi session loads at its start, and list
// it in ~/.pi/agent/settings.json's subagents.defaultSubagentOnlyExtensions,
// which foreground subagents load. It removes heredoc-guard.ts and its entry,
// now a handler of guards.ts. It copies open-questions.ts there too, for the
// main session only (the pane side of /open-questions; subagents have no
// pane), and removes criticality-colours.ts, now part of it; and draft.ts, the
// /draft command, unattended.ts, the unattended-window commands, ledger.ts
// (the session ledger's start and stop lines), refresh.ts (the /refresh
// command) and beep.ts (/beep-from and /mute), for the main session only too. It also copies
// the prompt templates in
// tools/prompts/ (e.g. /open-questions) into ~/.pi/agent/prompts/. Safe to
// rerun: the copies overwrite, the path is added only once, and what is gone
// stays gone. pi sessions already running load them at their next start or
// /reload: it ends by listing the tmux panes running pi, each needing /reload
// (RT3-Q5).
//
// Run: node tools/extensions/install.mjs
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const agent = join(homedir(), ".pi", "agent");
const target = join(agent, "extensions", "guards.ts");
mkdirSync(dirname(target), { recursive: true });
copyFileSync(join(dirname(fileURLToPath(import.meta.url)), "guards.ts"), target);
const heredoc = join(agent, "extensions", "heredoc-guard.ts");
rmSync(heredoc, { force: true });
const colours = join(agent, "extensions", "open-questions.ts");
copyFileSync(join(dirname(fileURLToPath(import.meta.url)), "open-questions.ts"), colours);
rmSync(join(agent, "extensions", "criticality-colours.ts"), { force: true });
const draft = join(agent, "extensions", "draft.ts");
copyFileSync(join(dirname(fileURLToPath(import.meta.url)), "draft.ts"), draft);
const unattended = join(agent, "extensions", "unattended.ts");
copyFileSync(join(dirname(fileURLToPath(import.meta.url)), "unattended.ts"), unattended);
const mainOnly = ["ledger.ts", "refresh.ts", "beep.ts"].map((name) => {
	const path = join(agent, "extensions", name);
	copyFileSync(join(dirname(fileURLToPath(import.meta.url)), name), path);
	return path;
});

const prompts = join(dirname(fileURLToPath(import.meta.url)), "..", "prompts");
mkdirSync(join(agent, "prompts"), { recursive: true });
const templates = readdirSync(prompts).filter((name) => name.endsWith(".md"));
for (const name of templates) copyFileSync(join(prompts, name), join(agent, "prompts", name));

const file = join(agent, "settings.json");
const settings = JSON.parse(readFileSync(file, "utf8"));
settings.subagents ??= {};
const list = (settings.subagents.defaultSubagentOnlyExtensions ?? []).filter((path) => path !== heredoc);
if (!list.includes(target)) list.push(target);
settings.subagents.defaultSubagentOnlyExtensions = list;
writeFileSync(`${file}.new`, `${JSON.stringify(settings, null, 2)}\n`);
chmodSync(`${file}.new`, statSync(file).mode);
renameSync(`${file}.new`, file);
console.log(`install: ${target}, ${colours}, ${draft}, ${unattended}, ${mainOnly.join(", ")} copied, ${heredoc} removed; ${file} lists only guards.ts in subagents.defaultSubagentOnlyExtensions; prompts copied to ${join(agent, "prompts")}: ${templates.join(" ")}`);

// The panes running pi: the pane's process is pi itself (`exec pi`, as team.sh
// starts seats), or a direct child of it (pi run from the pane's shell, as in
// the lead's pane: AW-Q78). pi's process is titled "node: pi" or "pi".
const panes = spawnSync("tmux", ["list-panes", "-a", "-F", "#{pane_pid} #{session_name}:#{window_index} #{window_name}"], { encoding: "utf8" });
// One -o per column: FreeBSD's ps takes all of "pid=,ppid=,args=" after the first = as pid's header.
const procs = spawnSync("ps", ["-ax", "-o", "pid=", "-o", "ppid=", "-o", "args="], { encoding: "utf8" });
if (panes.status !== 0) console.log("install: no tmux server read, so no list of panes to /reload");
else if (procs.status !== 0) console.log("install: no process list read (ps), so no list of panes to /reload");
else {
	const isPi = (args) => /^(node: pi|pi|node \S*\/pi)(\s|$)/.test(args);
	const table = procs.stdout.split("\n").filter(Boolean).map((line) => {
		const [, pid, ppid, args] = line.match(/^\s*(\d+)\s+(\d+)\s+(.*)$/) ?? [];
		return { pid, ppid, args: (args ?? "").trim() };
	});
	const pi = panes.stdout.split("\n").filter(Boolean).flatMap((line) => {
		const [pid, where, ...name] = line.split(" ");
		const runs = table.some((p) => (p.pid === pid || p.ppid === pid) && isPi(p.args));
		return runs ? [`${where} ${name.join(" ")}`] : [];
	});
	console.log(pi.length ? `install: each of these panes runs pi and needs /reload (or the reload_runtime tool, on your word):\n  ${pi.join("\n  ")}` : "install: no pane runs pi");
}
