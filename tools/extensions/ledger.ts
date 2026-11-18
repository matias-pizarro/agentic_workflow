// The session ledger's start and stop lines (the operator, 18 Nov 2026,
// RF-Q5; .scratch/refresh/). Installed by install.mjs, for the main session
// only.
// - On pi's session_start and session_shutdown, except for /reload, which
//   neither starts nor stops a session, it appends one line to the ledger:
//   "<YYYY-MM-DD hh:mm:ss TZ><TAB>start|stop<TAB><seat><TAB><session id><TAB>
//   <session name><TAB><pi's reason>". The seat is this pane's tmux window
//   name; the ledger's path is the tmux server option @team-ledger, which
//   team.sh sets. Outside tmux, or with no @team-ledger, it writes nothing.
// - It keeps this pane's tmux options @session-id and @session-name current,
//   so team.sh refresh can name the session it stops (the lead has no
//   registry line).
// - An append that fails is shown in the pane; pi carries on.
import { spawnSync } from "node:child_process";
import { appendFileSync } from "node:fs";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const flat = (s: string | undefined) => (s ?? "").replace(/[\t\r\n]+/g, " ");
const two = (n: number) => String(n).padStart(2, "0");

function zone(at: Date): string {
	return new Intl.DateTimeFormat("en-GB", { timeZoneName: "short" }).formatToParts(at).find((p) => p.type === "timeZoneName")?.value ?? "";
}

// One ledger line, newline included; a tab or newline inside a field becomes a space.
export function ledgerLine(event: string, seat: string, id: string, name: string | undefined, detail: string, at: Date = new Date(), tz: string = zone(at)): string {
	const stamp = `${at.getFullYear()}-${two(at.getMonth() + 1)}-${two(at.getDate())} ${two(at.getHours())}:${two(at.getMinutes())}:${two(at.getSeconds())} ${tz}`;
	return `${[stamp, event, seat, id, name, detail].map(flat).join("\t")}\n`;
}

// Whether a session_start / session_shutdown reason is a real start or stop.
export function logged(reason: string): boolean {
	return reason !== "reload";
}

function tmux(args: string[]): string | undefined {
	if (!process.env.TMUX) return undefined;
	const r = spawnSync("tmux", args, { encoding: "utf8" });
	return r.status === 0 ? r.stdout.trim() : undefined;
}

function mark(ctx: ExtensionContext) {
	const pane = process.env.TMUX_PANE;
	if (!pane) return;
	tmux(["set", "-p", "-t", pane, "@session-id", ctx.sessionManager.getSessionId()]);
	tmux(["set", "-p", "-t", pane, "@session-name", ctx.sessionManager.getSessionName() ?? ""]);
}

function write(event: "start" | "stop", reason: string, ctx: ExtensionContext) {
	const pane = process.env.TMUX_PANE;
	const path = tmux(["show", "-gv", "@team-ledger"]);
	if (!pane || !path) return;
	const seat = tmux(["display", "-p", "-t", pane, "#{window_name}"]) ?? "";
	try {
		appendFileSync(path, ledgerLine(event, seat, ctx.sessionManager.getSessionId(), ctx.sessionManager.getSessionName(), reason));
	} catch (e) {
		if (ctx.hasUI) ctx.ui.notify(`ledger: ${event} not written to ${path}: ${(e as Error).message}`, "error");
	}
}

export default function ledger(pi: ExtensionAPI) {
	pi.on("session_start", async (event, ctx) => {
		mark(ctx);
		if (logged(event.reason)) write("start", event.reason, ctx);
	});
	pi.on("session_info_changed", async (_event, ctx) => mark(ctx));
	pi.on("session_shutdown", async (event, ctx) => {
		if (logged(event.reason)) write("stop", event.reason, ctx);
	});
}
