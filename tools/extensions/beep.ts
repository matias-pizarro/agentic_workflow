// /beep-from and /mute: an audible signal when a seat needs the operator
// (AW-Q157, AW-Q158, the user, 21 Nov 2026 11:45; .scratch/agentic-workflow/beep.md).
// Installed by install.mjs, for the main session only.
// - `/beep-from all|<seat>` and `/mute all|<seat>`, typed in any pane, switch
//   the signal for the whole team or one seat (a tmux window's name). The
//   state is in tmux options, so a tmux server restart mutes everything again:
//   the server option @beep-all (on, or unset for muted) and a seat's window
//   option @beep (on or off), which overrides @beep-all. `all` also clears
//   every seat's own setting. No turn starts; the pane says what was set.
// - At the end of a turn (not aborted), a seat that is not muted plays the
//   signal once, `beep` three times, when its reply asks a new ❓ question (an
//   ID no earlier reply of the session holds) or its STATUS line newly says
//   waiting-for-PM (the previous STATUS line said another state, or there was
//   none). Agents play no signal themselves (rules.md, Team mechanics).
// Only typed input counts: a message from an extension or over RPC passes.
import { spawn, spawnSync } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const COMMAND = /^\s*\/(beep-from|mute)(?=\s|$)\s*([\s\S]*)$/;
const QUESTION = /❓\s*\**\s*([A-Z][A-Za-z0-9-]*-[QA][0-9]+[a-z]?)/gu;
const STATUS = /^\s*`?STATUS seat=\S+ state=(\S+)/gmu;
const SIGNAL = "for i in 1 2 3; do timeout 5 beep; sleep 0.3; done";

// A /beep-from or /mute line: its verb and target ("" when none), or undefined.
export function commandOf(text: string): { on: boolean; target: string } | undefined {
	const m = COMMAND.exec(text);
	if (!m) return undefined;
	return { on: m[1] === "beep-from", target: m[2].trim() };
}

const ids = (text: string) => new Set([...text.matchAll(QUESTION)].map((m) => m[1]));
const stateOf = (text: string) => [...text.matchAll(STATUS)].at(-1)?.[1];

// Whether the last reply calls for the signal, given the session's earlier replies.
export function calls(earlier: string[], last: string): boolean {
	const seen = new Set(earlier.flatMap((t) => [...ids(t)]));
	if ([...ids(last)].some((id) => !seen.has(id))) return true;
	if (stateOf(last) !== "waiting-for-PM") return false;
	const previous = earlier.map(stateOf).filter((s) => s !== undefined).at(-1);
	return previous !== "waiting-for-PM";
}

function tmux(args: string[]): { ok: boolean; out: string } {
	if (!process.env.TMUX) return { ok: false, out: "" };
	const r = spawnSync("tmux", args, { encoding: "utf8" });
	return { ok: r.status === 0, out: (r.stdout ?? "").trim() };
}

// The windows of the team's tmux server: id and name.
function windows(): { id: string; name: string }[] {
	const r = tmux(["list-windows", "-a", "-F", "#{window_id} #{window_name}"]);
	return r.out.split("\n").filter(Boolean).map((line) => {
		const at = line.indexOf(" ");
		return { id: line.slice(0, at), name: line.slice(at + 1) };
	});
}

// Set the switch; a sentence for the pane.
function setSwitch(on: boolean, target: string): { ok: boolean; say: string } {
	if (!process.env.TMUX) return { ok: false, say: "not in tmux: nothing to set" };
	const all = windows();
	if (target === "all") {
		const r = on ? tmux(["set", "-g", "@beep-all", "on"]) : tmux(["set", "-gu", "@beep-all"]);
		for (const w of all) tmux(["set", "-wu", "-t", w.id, "@beep"]);
		return r.ok ? { ok: true, say: on ? "beep on for every seat" : "every seat muted" } : { ok: false, say: "tmux refused to set @beep-all" };
	}
	const hits = all.filter((w) => w.name === target);
	if (hits.length === 0) return { ok: false, say: `no seat named ${target} (a tmux window's name)` };
	let ok = true;
	for (const w of hits) ok = tmux(["set", "-w", "-t", w.id, "@beep", on ? "on" : "off"]).ok && ok;
	return ok ? { ok: true, say: on ? `beep on for ${target}` : `${target} muted` } : { ok: false, say: `tmux refused to set @beep on ${target}` };
}

// Whether this pane's seat is switched on.
function switchedOn(): boolean {
	const pane = process.env.TMUX_PANE;
	if (!pane || !process.env.TMUX) return false;
	const own = tmux(["show", "-wv", "-t", pane, "@beep"]).out;
	if (own === "on" || own === "off") return own === "on";
	return tmux(["show", "-gv", "@beep-all"]).out === "on";
}

function replies(ctx: ExtensionContext): string[] {
	return ctx.sessionManager.getBranch().flatMap((entry) => {
		if (entry.type !== "message" || entry.message.role !== "assistant") return [];
		const text = entry.message.content
			.filter((c): c is { type: "text"; text: string } => c.type === "text")
			.map((c) => c.text)
			.join("\n");
		return text ? [text] : [];
	});
}

export default function beep(pi: ExtensionAPI) {
	pi.on("input", async (event, ctx) => {
		if (event.source !== "interactive") return { action: "continue" };
		const cmd = commandOf(event.text);
		if (!cmd) return { action: "continue" };
		const verb = cmd.on ? "/beep-from" : "/mute";
		const r = cmd.target
			? setSwitch(cmd.on, cmd.target)
			: { ok: false, say: `usage: ${verb} all|<seat>` };
		if (ctx.hasUI) ctx.ui.notify(r.ok ? r.say : `${verb} not applied: ${r.say}`, r.ok ? "info" : "warning");
		return { action: "handled" };
	});

	pi.on("agent_settled", async (event, ctx) => {
		if (event.aborted) return;
		const all = replies(ctx);
		const last = all.at(-1);
		if (last === undefined || !calls(all.slice(0, -1), last) || !switchedOn()) return;
		spawn("sh", ["-c", SIGNAL], { stdio: "ignore", detached: true }).unref();
	});
}
