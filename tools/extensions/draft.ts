// /draft <description>: ask the lead to task an agent with it (the user, 18 Nov
// 2026, AW-Q68–Q74). Installed by install.mjs, for the main session only.
// - In the lead's pane (tmux pane option @role=lead), the typed line becomes
//   the text of draftText(): the description verbatim, after a time stamp,
//   since guards.ts stamps no /command. The lead then chooses the seat, its
//   working directory, branch and worktree, and writes the task file.
// - In any other pane it is relayed to the lead, on one line, with `team.sh report` (the
//   path team.sh puts in the tmux server option @team-sh), and the seat's agent
//   starts no turn; the pane says so. If the relay fails, the pane says why and
//   the typed line goes back into the input box.
// - With no description, nothing is sent: the pane shows the usage.
// Only typed input counts: a message from an extension or over RPC passes.
// It rewrites the typed line, as /o does, so it is not listed in completion.
import { spawnSync } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DRAFT = /^\s*\/draft(?=\s|$)\s*([\s\S]*)$/;
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const USAGE = "usage: /draft <description>";

export function draftText(description: string, now: Date = new Date()): string {
	const hh = String(now.getHours()).padStart(2, "0");
	const mm = String(now.getMinutes()).padStart(2, "0");
	const task = description.trim();
	return [
		`[${now.getDate()} ${MONTHS[now.getMonth()]} ${hh}:${mm}] Task an agent with ${task}${/[.!?]$/.test(task) ? "" : "."}`,
		"The work runs in parallel with the other workflows: it neither blocks them nor is blocked by them. " +
			"It starts by settling the task's perimeter with me using `grill-with-docs`, then proposes how to follow: " +
			"`implement`, `to-spec` + `to-tickets`, a new task on the board, or something else altogether.",
		"Choose at your discretion the seat (a new one or an existing one) and its name, its working directory, " +
			"and its branch and worktree, if any.",
	].join("\n");
}

// The description of a /draft line, "" for a bare /draft, or undefined for another line.
export function draftOf(text: string): string | undefined {
	return DRAFT.exec(text)?.[1].trim();
}

function tmuxOut(args: string[]): string | undefined {
	if (!process.env.TMUX) return undefined;
	const r = spawnSync("tmux", args, { encoding: "utf8" });
	return r.status === 0 && r.stdout.trim() ? r.stdout.trim() : undefined;
}

// Relay to the lead: "relayed", "queued" (no deliverer started yet), or why not.
function relay(text: string): "relayed" | "queued" | { failure: string } {
	const pane = process.env.TMUX_PANE;
	const seat = pane ? tmuxOut(["display", "-p", "-t", pane, "#{window_name}"]) : undefined;
	if (!seat) return { failure: "this pane's tmux window name cannot be read" };
	const team = tmuxOut(["show", "-gv", "@team-sh"]);
	if (!team) return { failure: "no team.sh path (tmux option @team-sh); it is set at the next team.sh send, report, spawn or revive" };
	// One line: team.sh types the report into the lead's pane, where a newline is dropped, gluing the lines.
	const line = `${seat}: /draft typed in ${seat}'s pane: ${text.replace(/\s*\n\s*/g, " ")}`;
	// TEAM_QIDS_SKIP: a "❓ <ID>" in the description is text, not this seat's question (AW-Q75).
	const r = spawnSync("sh", [team, "report", line], { encoding: "utf8", env: { ...process.env, TEAM_QIDS_SKIP: "1" } });
	if (r.status !== 0) return { failure: `team.sh report exited ${r.status ?? r.signal}: ${(r.stderr || r.stdout || r.error?.message || "").trim()}` };
	// team.sh keeps the message queued when it cannot start its deliverer (AW-Q77).
	return /no deliverer started/.test(r.stderr) ? "queued" : "relayed";
}

export default function draft(pi: ExtensionAPI) {
	pi.on("input", async (event, ctx) => {
		if (event.source !== "interactive") return { action: "continue" };
		const description = draftOf(event.text);
		if (description === undefined) return { action: "continue" };
		if (description === "") {
			if (ctx.hasUI) ctx.ui.notify(USAGE, "warning");
			return { action: "handled" };
		}
		const text = draftText(description);
		const pane = process.env.TMUX_PANE;
		if (pane && tmuxOut(["show", "-pv", "-t", pane, "@role"]) === "lead") return { action: "transform", text };
		const result = relay(text);
		if (ctx.hasUI) {
			if (result === "relayed") ctx.ui.notify("/draft relayed to the lead (team.sh report); this pane carries on", "info");
			else if (result === "queued")
				ctx.ui.notify("/draft queued for the lead, not yet delivered: delivery starts with the next team.sh message; this pane carries on", "warning");
			else {
				ctx.ui.notify(`/draft not relayed: ${result.failure}. Your line is back in the input box.`, "error");
				ctx.ui.setEditorText(event.text);
			}
		}
		return { action: "handled" };
	});
}
