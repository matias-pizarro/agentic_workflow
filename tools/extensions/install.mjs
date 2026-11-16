#!/usr/bin/env node
// Install the guards for this user's pi: copy guards.ts into
// ~/.pi/agent/extensions/, which every pi session loads at its start, and list
// it in ~/.pi/agent/settings.json's subagents.defaultSubagentOnlyExtensions,
// which foreground subagents load. It removes heredoc-guard.ts and its entry,
// now a handler of guards.ts. It also copies the prompt templates in
// tools/prompts/ (e.g. /open-questions) into ~/.pi/agent/prompts/. Safe to
// rerun: the copies overwrite, the path is added only once, and what is gone
// stays gone. pi sessions already running load them at their next start or
// /reload.
//
// Run: node tools/extensions/install.mjs
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
console.log(`install: ${target} copied, ${heredoc} removed; ${file} lists only the former in subagents.defaultSubagentOnlyExtensions; prompts copied to ${join(agent, "prompts")}: ${templates.join(" ")}`);
