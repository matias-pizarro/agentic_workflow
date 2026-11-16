// /open-questions, the pane side (tools/prompts/open-questions.md prints the
// questions). Installed by install.mjs, for the main session only.
// - A reply line starting with 🔴, 🟠 or 🟡 shows the rest of its text in red,
//   orange or yellow; its backticks are dropped, since pi's code styling would
//   end the colour. Display only: the session and the model's context keep the
//   reply as written (pi docs, extensions.md, registerMarkdownTransformer).
// - The line "Open questions for the operator: none" shows green, with NONE in
//   capitals (the user, 16 Nov).
// - /o is a shortcut for /open-questions: the input is rewritten before pi
//   expands templates (the user, 16 Nov). It is not listed in completion.
// - After a turn started by /open-questions, the input box is filled with one
//   row per question, in the reply's order: "<marker> <criticality> · <ID>:
//   Yes", so the operator edits only the answers that are not "yes". Only an
//   empty box is filled. While it holds that text, team.sh delivers nothing
//   to this pane: it waits for an empty input box. The rows' text is not
//   coloured: the coloured marker is enough (the user, 16 Nov).
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const COLOURS: Record<string, string> = {
	"🔴": "\x1b[38;5;196m", // high
	"🟠": "\x1b[38;5;208m", // medium
	"🟡": "\x1b[38;5;220m", // low
};
const FG_RESET = "\x1b[39m";
const GREEN = "\x1b[38;5;40m";
const NONE_LINE = /^(\s*)`?(Open questions for the operator: )none`?\s*$/gimu;
const MARKED_LINE = /^(\s*)(🔴|🟠|🟡)(.*)$/gmu;
const CRITICALITY = /^\s*(🔴|🟠|🟡)\s*(high|medium|low)\b/iu;
const QUESTION = /❓\s*\**\s*([A-Z][A-Za-z0-9-]*-Q[0-9]+[a-z]?)/u;

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
				.replace(NONE_LINE, (_m: string, indent: string, lead: string) => `${indent}${GREEN}${lead}NONE${FG_RESET}`),
		{ messageTypes: ["assistant"] },
	);

	let asked = false;
	pi.on("input", async (event) => {
		if (/^\s*\/o\s*$/.test(event.text)) {
			asked = true;
			return { action: "transform", text: "/open-questions" };
		}
		if (/^\s*\/open-questions\b/.test(event.text)) asked = true;
		return { action: "continue" };
	});

	pi.on("agent_settled", async (event, ctx) => {
		if (!asked) return;
		asked = false;
		if (event.aborted || !ctx.hasUI || ctx.ui.getEditorText().trim() !== "") return;
		const rows = answerRows(lastAssistantText(ctx) ?? "");
		if (rows.length > 0) ctx.ui.setEditorText(rows.join("\n"));
	});
}
