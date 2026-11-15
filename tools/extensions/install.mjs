#!/usr/bin/env node
// Install the guards for this user's pi: copy guards.ts into
// ~/.pi/agent/extensions/, which every pi session loads at its start, and list
// it in ~/.pi/agent/settings.json's subagents.defaultSubagentOnlyExtensions,
// which foreground subagents load. It removes heredoc-guard.ts and its entry,
// now a handler of guards.ts. Safe to rerun: the copy overwrites, the path is
// added only once, and what is gone stays gone. pi sessions already running
// load it at their next start or /reload.
//
// Run: node tools/extensions/install.mjs
import { copyFileSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const agent = join(homedir(), ".pi", "agent");
const target = join(agent, "extensions", "guards.ts");
mkdirSync(dirname(target), { recursive: true });
copyFileSync(join(dirname(fileURLToPath(import.meta.url)), "guards.ts"), target);
const heredoc = join(agent, "extensions", "heredoc-guard.ts");
rmSync(heredoc, { force: true });

const file = join(agent, "settings.json");
const settings = JSON.parse(readFileSync(file, "utf8"));
settings.subagents ??= {};
const list = (settings.subagents.defaultSubagentOnlyExtensions ?? []).filter((path) => path !== heredoc);
if (!list.includes(target)) list.push(target);
settings.subagents.defaultSubagentOnlyExtensions = list;
writeFileSync(`${file}.new`, `${JSON.stringify(settings, null, 2)}\n`);
renameSync(`${file}.new`, file);
console.log(`install: ${target} copied, ${heredoc} removed; ${file} lists only the former in subagents.defaultSubagentOnlyExtensions`);
