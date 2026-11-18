// /refresh <seat>…|all|lead: hand seats to new sessions in their panes (the
// operator, 18 Nov 2026, RF-Q1, RF-Q11, RF-Q12; .scratch/refresh/). Installed
// by install.mjs, for the main session only.
// - In the lead's pane (tmux pane option @role=lead) it runs `team.sh refresh
//   <names> "<the typed line>" "lead pane hh:mm"` (the path team.sh puts in
//   the tmux server option @team-sh) and shows what it printed. team.sh checks
//   the names, starts one background run per seat and returns at once; each
//   run reports to the lead when it ends. The lead's agent starts no turn.
//   If team.sh refuses, the pane says why and the typed line goes back into
//   the input box.
// - In any other pane, and with no name, it is refused there, with the usage.
// Only typed input counts: a message from an extension or over RPC passes.
import { spawnSync } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const REFRESH = /^\s*\/refresh(?=\s|$)\s*([\s\S]*)$/;
const USAGE = "usage, in the lead's pane: /refresh <seat> [<seat>…] | all | lead";

// The names of a /refresh line, [] for a bare /refresh, or undefined for another line.
export function refreshOf(text: string): string[] | undefined {
	const rest = REFRESH.exec(text)?.[1];
	return rest === undefined ? undefined : rest.split(/\s+/).filter(Boolean);
}

// Where and when the operator typed it, as team.sh go and refresh take it.
export function source(now: Date = new Date()): string {
	return `lead pane ${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
}

function tmuxOut(args: string[]): string | undefined {
	if (!process.env.TMUX) return undefined;
	const r = spawnSync("tmux", args, { encoding: "utf8" });
	return r.status === 0 && r.stdout.trim() ? r.stdout.trim() : undefined;
}

export default function refresh(pi: ExtensionAPI) {
	pi.on("input", async (event, ctx) => {
		if (event.source !== "interactive") return { action: "continue" };
		const names = refreshOf(event.text);
		if (names === undefined) return { action: "continue" };
		const pane = process.env.TMUX_PANE;
		const lead = pane !== undefined && tmuxOut(["show", "-pv", "-t", pane, "@role"]) === "lead";
		if (!lead || names.length === 0) {
			if (ctx.hasUI) ctx.ui.notify(lead ? USAGE : `/refresh refused here: it works only in the lead's pane. ${USAGE}`, "warning");
			return { action: "handled" };
		}
		const team = tmuxOut(["show", "-gv", "@team-sh"]);
		const r = team
			? spawnSync("sh", [team, "refresh", ...names, event.text.trim(), source()], { encoding: "utf8" })
			: undefined;
		const out = r ? `${r.stdout}${r.stderr}`.trim() : "no team.sh path (tmux option @team-sh); it is set at the next team.sh send, report, spawn or revive";
		const ok = r !== undefined && r.status === 0;
		if (ctx.hasUI) {
			ctx.ui.notify(ok ? out : `/refresh not started: ${out}. Your line is back in the input box.`, ok ? "info" : "error");
			if (!ok) ctx.ui.setEditorText(event.text);
		}
		return { action: "handled" };
	});
}
