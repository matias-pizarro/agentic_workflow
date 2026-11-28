// /beep-from and /mute: an audible signal when a seat needs the operator
// (AW-Q157, AW-Q158, the user, 21 Nov 2026 11:45; .scratch/agentic-workflow/beep.md).
// Installed by install.mjs, for the main session only.
// - `/beep-from all|<seat>` and `/mute all|<seat>`, typed in any pane, switch
//   the signal for the whole team or one seat (a tmux window's name). The
//   state is in tmux options, so a tmux server restart mutes everything again:
//   the global option @beep-all (on, or unset for muted) and a seat's window
//   option @beep (on or off), which overrides @beep-all. `all` also clears
//   every seat's own setting. No turn starts; the pane says what was set.
// - At the end of a turn (not aborted), a seat that is not muted plays the
//   signal once, `beep` three times, when its turn (every assistant text since
//   the last user message, AW-Q159) asks a new ❓ question (an ID no earlier
//   reply of the session holds) or its STATUS line newly says
//   waiting-for-PM (the previous STATUS line said another state, or there was
//   none). Agents play no signal themselves (rules.md, Team mechanics).
// - A turn that ends aborted or in error (its last assistant message's
//   stopReason) marks the seat blocked, so the board and the red tab show it
//   (RT4-Q3 (a), the operator, "ok", 27 Nov 2026 13:12): the window options
//   @state=blocked, @worst=high and @ask="turn failed: <error>; re-send your
//   message", and @for unset; the signal plays unless the seat is muted. The
//   seat's next STATUS line sets them again (open-questions.ts). An abort the
//   operator made with Esc is marked too.
// Only typed input counts: a message from an extension or over RPC passes.
import { spawn, spawnSync } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const COMMAND = /^\s*\/(beep-from|mute)(?=\s|$)\s*([\s\S]*)$/;
const QUESTION = /❓\s*\**\s*([A-Z][A-Za-z0-9-]*-[QA][0-9]+[a-z]?)/gu;
const STATUS = /^\s*`?STATUS seat=\S+ state=(\S+)/gmu;
const SIGNAL = "for i in 1 2 3; do timeout 5 beep; sleep 0.3; done";
const FAILED_TAB = "bg=colour88,fg=colour254"; // open-questions.ts's high

// Why the turn failed, from its last assistant message (stopReason aborted or
// error), or undefined when it did not; an aborted run with no assistant
// message after the last user message counts as aborted.
export function failureOf(
	messages: { role: string; stopReason?: string; errorMessage?: string }[],
	aborted: boolean,
): string | undefined {
	const last = messages.filter((m) => m.role === "user" || m.role === "assistant").at(-1);
	if (last?.role === "assistant" && (last.stopReason === "aborted" || last.stopReason === "error")) {
		const why = (last.errorMessage ?? "").replace(/\s+/gu, " ").replace(/"/gu, "'").trim();
		return (why || last.stopReason).slice(0, 120);
	}
	return aborted ? "aborted" : undefined;
}

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
	const r = spawnSync("tmux", args, { encoding: "utf8", timeout: 5000 });
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

// Mark this pane's window blocked, for the board and the tab (RT4-Q3).
function markFailed(why: string) {
	const pane = process.env.TMUX_PANE;
	if (!pane || !process.env.TMUX) return;
	const set = (option: string, value?: string) =>
		tmux(value === undefined ? ["set", "-wu", "-t", pane, option] : ["set", "-w", "-t", pane, option, value]);
	set("@state", "blocked");
	set("@for");
	set("@worst", "high");
	set("@ask", `turn failed: ${why}; re-send your message`);
	set("window-status-style", FAILED_TAB);
}

// Whether this pane's seat is switched on.
function switchedOn(): boolean {
	const pane = process.env.TMUX_PANE;
	if (!pane || !process.env.TMUX) return false;
	const own = tmux(["show", "-wv", "-t", pane, "@beep"]).out;
	if (own === "on" || own === "off") return own === "on";
	return tmux(["show", "-gv", "@beep-all"]).out === "on";
}

// The session's assistant texts before the last user message, and the last
// turn's (every assistant text after it) joined into one.
function replies(ctx: ExtensionContext): { earlier: string[]; turn: string } {
	const earlier: string[] = [];
	let turn: string[] = [];
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "message") continue;
		if (entry.message.role === "user") {
			earlier.push(...turn);
			turn = [];
			continue;
		}
		if (entry.message.role !== "assistant") continue;
		const text = entry.message.content
			.filter((c): c is { type: "text"; text: string } => c.type === "text")
			.map((c) => c.text)
			.join("\n");
		if (text) turn.push(text);
	}
	return { earlier, turn: turn.join("\n") };
}

export default function beep(pi: ExtensionAPI) {
	// Nothing in a subagent (CS-Q121): pi-subagents runs a background subagent
	// as a child process with PI_SUBAGENT_CHILD=1, which inherits the seat's
	// TMUX_PANE and would write the seat's ledger lines and pane options as its
	// own. A foreground subagent runs in the seat's process without that marker,
	// but loads only settings.json's subagents.defaultSubagentOnlyExtensions,
	// which install.mjs keeps to guards.ts, so this file never runs there.
	if (process.env.PI_SUBAGENT_CHILD === "1") return;
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
		const messages = ctx.sessionManager
			.getBranch()
			.flatMap((e) => (e.type === "message" ? [e.message as { role: string; stopReason?: string; errorMessage?: string }] : []));
		const failed = failureOf(messages, event.aborted);
		if (failed) {
			markFailed(failed);
			if (switchedOn()) spawn("sh", ["-c", SIGNAL], { stdio: "ignore", detached: true }).unref();
			return;
		}
		const { earlier, turn } = replies(ctx);
		if (!turn || !calls(earlier, turn) || !switchedOn()) return;
		spawn("sh", ["-c", SIGNAL], { stdio: "ignore", detached: true }).unref();
	});
}
