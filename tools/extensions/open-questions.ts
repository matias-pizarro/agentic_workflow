// /open-questions, the pane side (tools/prompts/open-questions.md prints the
// questions). Installed by install.mjs, for the main session only.
// - A reply line starting with 🔴, 🟠 or 🟡 shows the rest of its text in red,
//   orange or yellow; its backticks are dropped, since pi's code styling would
//   end the colour. Display only: the session and the model's context keep the
//   reply as written (pi docs, extensions.md, registerMarkdownTransformer).
// - The line "Open questions for the operator: none" shows green, with NONE in
//   capitals, and so does a line "No questions of mine are open." (the user,
//   16 Nov).
// - /o is a shortcut for /open-questions: the input is rewritten before pi
//   expands templates (the user, 16 Nov). It is not listed in completion.
// - After a turn started by /open-questions, the input box is filled with one
//   row per question, in the reply's order: "<marker> <criticality> · <ID>:
//   Yes", so the operator edits only the answers that are not "yes". Only an
//   empty box is filled. While it holds that text, team.sh delivers nothing
//   to this pane: it waits for an empty input box. The rows' text is not
//   coloured: the coloured marker is enough (the user, 16 Nov).
// - The seat's tmux window tab is coloured by what waits on the operator (the
//   user, 16 Nov): red, orange or yellow after the most critical question in
//   a reply that asks any; green after a NONE or "No questions of mine are
//   open." line, or once the operator types in the pane (not a "Lead:"
//   message, not a /command); a reply without questions leaves it as it is.
// - While the agent works, its window carries the tmux option @working, which
//   the tab format in tmux.conf shows as ⚡ after the name (the user, 16 Nov).
import { spawnSync } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const COLOURS: Record<string, string> = {
	"🔴": "\x1b[38;5;196m", // high
	"🟠": "\x1b[38;5;208m", // medium
	"🟡": "\x1b[38;5;220m", // low
};
const FG_RESET = "\x1b[39m";
const GREEN = "\x1b[38;5;40m";
const NONE_LINE = /^(\s*)`?(Open questions for the operator: )none`?\s*$/gimu;
const NO_QUESTIONS_LINE = /^(\s*)(No questions of mine are open\.)\s*$/gmu;
const MARKED_LINE = /^(\s*)(🔴|🟠|🟡)(.*)$/gmu;
const CRITICALITY = /^\s*(🔴|🟠|🟡)\s*(high|medium|low)\b/iu;
const QUESTION = /❓\s*\**\s*([A-Z][A-Za-z0-9-]*-Q[0-9]+[a-z]?)/u;
const NO_OPEN = /^\s*`?(Open questions for the operator: none`?|No questions of mine are open\.)\s*$/imu;
const TABS: Record<string, string> = {
	"🔴": "bg=colour196,fg=black",
	"🟠": "bg=colour208,fg=black",
	"🟡": "bg=colour220,fg=black",
	green: "bg=colour34,fg=black",
};
const RANK = ["🔴", "🟠", "🟡"];

// The tab's colour a reply asks for: the most critical marker above a ❓ line,
// "green" when it says nothing is open, or undefined to leave the tab as is.
export function tabFor(reply: string): string | undefined {
	if (NO_OPEN.test(reply)) return "green";
	let marker = "";
	let worst = -1;
	for (const line of reply.split("\n")) {
		const c = line.match(CRITICALITY);
		if (c) marker = c[1];
		if (QUESTION.test(line)) {
			const rank = marker ? RANK.indexOf(marker) : RANK.length - 1;
			if (worst < 0 || rank < worst) worst = rank;
			marker = "";
		}
	}
	return worst < 0 ? undefined : RANK[worst];
}

// Run `tmux set -w <flags> -t <this pane> <option> [value]`; outside tmux, or
// if tmux fails, nothing.
function setWindowOption(flags: string[], option: string, value?: string) {
	const pane = process.env.TMUX_PANE;
	if (!pane || !process.env.TMUX) return;
	const args = ["set", "-w", ...flags, "-t", pane, option];
	if (value !== undefined) args.push(value);
	spawnSync("tmux", args, { stdio: "ignore" });
}
function colourTab(tab: string) {
	setWindowOption([], "window-status-style", TABS[tab]);
}
function markWorking(on: boolean) {
	if (on) setWindowOption([], "@working", "1");
	else setWindowOption(["-u"], "@working");
}

// The rows to prefill from the reply's text: each ❓ ID, with the criticality
// line that came before it, if any.
export function answerRows(reply: string): string[] {
	const rows: string[] = [];
	let criticality = "";
	for (const line of reply.split("\n")) {
		const c = line.match(CRITICALITY);
		if (c) criticality = `${c[1]} ${c[2].toLowerCase()} · `;
		const q = line.match(QUESTION);
		if (q) {
			rows.push(`${criticality}${q[1]}: Yes`);
			criticality = "";
		}
	}
	return rows;
}

function lastAssistantText(ctx: ExtensionContext): string | undefined {
	const branch = ctx.sessionManager.getBranch();
	for (let i = branch.length - 1; i >= 0; i--) {
		const entry = branch[i];
		if (entry.type !== "message" || entry.message.role !== "assistant") continue;
		const text = entry.message.content
			.filter((c): c is { type: "text"; text: string } => c.type === "text")
			.map((c) => c.text)
			.join("\n");
		if (text) return text;
	}
	return undefined;
}

export default function openQuestions(pi: ExtensionAPI) {
	pi.registerMarkdownTransformer(
		(markdown: string) =>
			markdown
				.replace(MARKED_LINE, (_m: string, indent: string, dot: string, rest: string) =>
					`${indent}${dot}${COLOURS[dot]}${rest.replaceAll("`", "")}${FG_RESET}`,
				)
				.replace(NONE_LINE, (_m: string, indent: string, lead: string) => `${indent}${GREEN}${lead}NONE${FG_RESET}`)
				.replace(NO_QUESTIONS_LINE, (_m: string, indent: string, text: string) => `${indent}${GREEN}${text}${FG_RESET}`),
		{ messageTypes: ["assistant"] },
	);

	let asked = false;
	pi.on("input", async (event) => {
		if (event.source === "interactive" && !/^\s*(Lead:|\/)/.test(event.text)) colourTab("green");
		if (/^\s*\/o\s*$/.test(event.text)) {
			asked = true;
			return { action: "transform", text: "/open-questions" };
		}
		if (/^\s*\/open-questions\b/.test(event.text)) asked = true;
		return { action: "continue" };
	});

	pi.on("agent_start", async () => markWorking(true));

	pi.on("agent_settled", async (event, ctx) => {
		markWorking(false);
		if (!event.aborted) {
			const tab = tabFor(lastAssistantText(ctx) ?? "");
			if (tab) colourTab(tab);
		}
		if (!asked) return;
		asked = false;
		if (event.aborted || !ctx.hasUI || ctx.ui.getEditorText().trim() !== "") return;
		const rows = answerRows(lastAssistantText(ctx) ?? "");
		if (rows.length > 0) ctx.ui.setEditorText(rows.join("\n"));
	});
}
