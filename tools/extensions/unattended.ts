// The unattended-window commands (rules.md rule 15, docs/unattended-windows.md;
// the user, 18 Nov 2026, ON-Q3–Q5). Installed by install.mjs, for the main
// session only.
//   /unattended-window <intent>   opens the grill
//   /abort-unattended-window      drops it, before the start only
//   /start-unattended-window      starts the window, after the grill
//   /end-unattended-window        ends it: stop and hold, the morning report
// - Only typed input counts: a message from an extension or over RPC passes.
// - In the lead's pane (tmux pane option @role=lead), a command valid in the
//   window's current state becomes a stamped instruction to the lead (guards.ts
//   stamps no /command). The state lives in that pane's tmux option
//   @unattended: unset, "grill" or "open"; it survives a restart of the lead's
//   pi in the same pane.
// - A command out of order, or typed in any other pane, is refused in the pane;
//   the agent starts no turn and the line goes back into the input box.
import { spawnSync } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export type Command = "open" | "abort" | "start" | "end";
export type State = "" | "grill" | "open";

const NAMES: Record<Command, string> = {
	open: "/unattended-window",
	abort: "/abort-unattended-window",
	start: "/start-unattended-window",
	end: "/end-unattended-window",
};
const LINE = /^\s*\/(unattended-window|abort-unattended-window|start-unattended-window|end-unattended-window)(?=\s|$)\s*([\s\S]*)$/;
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const DOC = "agentic_workflow's docs/unattended-windows.md";

// The command of a typed line and its argument, or undefined for another line.
export function parse(text: string): { command: Command; arg: string } | undefined {
	const m = LINE.exec(text);
	if (!m) return undefined;
	const command = (Object.keys(NAMES) as Command[]).find((c) => NAMES[c] === `/${m[1]}`)!;
	return { command, arg: m[2].trim() };
}

// The state after the command, or why it is refused.
export function next(state: State, command: Command, arg: string): { state: State } | { refused: string } {
	if (command === "open") {
		if (!arg) return { refused: "usage: /unattended-window <intent>" };
		if (state === "grill") return { refused: "a window's grill is already running: answer it, /start-unattended-window or /abort-unattended-window" };
		if (state === "open") return { refused: "a window is already running: /end-unattended-window ends it" };
		return { state: "grill" };
	}
	if (arg) return { refused: `usage: ${NAMES[command]}, with nothing after it` };
	if (command === "abort") {
		if (state === "grill") return { state: "" };
		return { refused: state === "open" ? "the window has started: /abort-unattended-window is valid only before the start; /end-unattended-window ends it" : "no window's grill is running" };
	}
	if (command === "start") {
		if (state === "grill") return { state: "open" };
		return { refused: state === "open" ? "the window has already started" : "no grill has run: /unattended-window <intent> opens one" };
	}
	if (state === "open") return { state: "" };
	return { refused: state === "grill" ? "the window has not started: /abort-unattended-window drops its grill" : "no window is running" };
}

export function instruction(command: Command, arg: string, now: Date = new Date()): string {
	const hh = String(now.getHours()).padStart(2, "0");
	const mm = String(now.getMinutes()).padStart(2, "0");
	const stamp = `[${now.getDate()} ${MONTHS[now.getMonth()]} ${hh}:${mm}] ${NAMES[command]}`;
	switch (command) {
		case "open":
			return `${stamp} ${arg}\nThis is my intent for an unattended window (rule 15). Run the opening grill, as ${DOC} says under "Opening: the grill". Nothing starts before my /start-unattended-window.`;
		case "abort":
			return `${stamp}\nDrop the unattended window's grill: nothing starts (${DOC}).`;
		case "start":
			return `${stamp}\nStart the unattended window on the terms settled in the grill, as ${DOC} says under "Start". Rule 15 applies from now until my /end-unattended-window.`;
		case "end":
			return `${stamp}\nEnd the unattended window: stop and hold, then the morning report and the close, as ${DOC} says under "End".`;
	}
}

function tmux(args: string[]): { ok: boolean; out: string } {
	if (!process.env.TMUX) return { ok: false, out: "" };
	const r = spawnSync("tmux", args, { encoding: "utf8" });
	return { ok: r.status === 0, out: (r.stdout ?? "").trim() };
}

export default function unattended(pi: ExtensionAPI) {
	pi.on("input", async (event, ctx) => {
		if (event.source !== "interactive") return { action: "continue" };
		const line = parse(event.text);
		if (!line) return { action: "continue" };
		const refuse = (why: string) => {
			if (ctx.hasUI) {
				ctx.ui.notify(`${NAMES[line.command]} refused: ${why}. Your line is back in the input box.`, "error");
				ctx.ui.setEditorText(event.text);
			}
			return { action: "handled" as const };
		};
		const pane = process.env.TMUX_PANE;
		if (!pane || tmux(["show", "-pv", "-t", pane, "@role"]).out !== "lead") return refuse("it is valid only in the lead's pane");
		const read = tmux(["show", "-pqv", "-t", pane, "@unattended"]);
		if (!read.ok) return refuse("this pane's tmux option @unattended cannot be read");
		const state = (["grill", "open"].includes(read.out) ? read.out : "") as State;
		const after = next(state, line.command, line.arg);
		if ("refused" in after) return refuse(after.refused);
		const write = after.state ? tmux(["set", "-p", "-t", pane, "@unattended", after.state]) : tmux(["set", "-pu", "-t", pane, "@unattended"]);
		if (!write.ok) return refuse("this pane's tmux option @unattended cannot be set");
		return { action: "transform", text: instruction(line.command, line.arg) };
	});
}
