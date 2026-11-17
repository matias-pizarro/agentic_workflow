// Guards: one pi extension, one tool_call handler per guard. Installed by
// tools/extensions/install.mjs (README, "Guards").
import type { ExtensionAPI, ExtensionContext, ToolCallEvent, ToolCallEventResult } from "@earendil-works/pi-coding-agent";

// sibling-guard (retro of 15 Nov 2026, candidate 2). pi runs the tool calls of
// one assistant message at the same time: "sibling tool calls from the same
// assistant message are preflighted sequentially, then executed concurrently"
// (pi's docs/extensions.md, "tool_call"). A command issued beside a write or an
// edit may read the file half-written: a `git commit` beside an edit committed
// the file emptied (skills 8639493). So a bash call is refused when the
// assistant message that holds it also holds a write or an edit. For tool_call,
// ctx.sessionManager is "synchronized through the current assistant message"
// (same docs, "ctx.sessionManager"), so that message is the branch's last
// assistant message.
//
// It also refuses a bash call beside another bash call when either runs a git
// step that changes state, or merge-ready (RT3-Q5): a merge issued beside
// `commit; merge-ready` went in without merge-ready's pass (16 Nov).
const GIT_STEP =
	/\bgit\b[^;&|\n]*\b(?:commit|merge(?!-base)|push|pull|rebase|reset|checkout|switch|tag|cherry-pick|revert|stash|worktree|restore|add|rm|mv)\b|merge-ready/;
const GIT_SIBLING_REFUSAL =
	"sibling-guard: refused. Another command in this same message runs at the same time as this git or merge-ready step, " +
	"so each may see the other half done. Run the command in your next message: one git step per message, in order.";
const SIBLING_REFUSAL =
	"sibling-guard: refused. A write or edit in this same message runs at the same time as this command, " +
	"so the command may read the file half-written (empty or stale). " +
	"Run the command in your next message, after the write's result.";

export function siblingGuard(event: ToolCallEvent, ctx: ExtensionContext): ToolCallEventResult | undefined {
	if (event.toolName !== "bash") return undefined;
	const branch = ctx.sessionManager.getBranch();
	for (let i = branch.length - 1; i >= 0; i--) {
		const entry = branch[i];
		if (entry.type !== "message" || entry.message.role !== "assistant") continue;
		const writes = entry.message.content.some(
			(part) => part.type === "toolCall" && (part.name === "write" || part.name === "edit"),
		);
		if (writes) return { block: true, reason: SIBLING_REFUSAL };
		const commands = entry.message.content.flatMap((part) =>
			part.type === "toolCall" && part.name === "bash" ? [String((part.arguments as { command?: unknown }).command ?? "")] : [],
		);
		return commands.length > 1 && commands.some((command) => GIT_STEP.test(command))
			? { block: true, reason: GIT_SIBLING_REFUSAL }
			: undefined;
	}
	return undefined;
}

// time-stamp (RT3-Q3): each message the operator types, other than a
// /command, starts with its local time, "[17 Nov 12:59] ", so a quoted time is
// the stamp, never an estimate. Messages team.sh types into a pane are stamped
// with their delivery time.
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
export function stamp(text: string, now: Date = new Date()): string {
	const hh = String(now.getHours()).padStart(2, "0");
	const mm = String(now.getMinutes()).padStart(2, "0");
	return `[${now.getDate()} ${MONTHS[now.getMonth()]} ${hh}:${mm}] ${text}`;
}

export function timeStamp(event: { text: string; source: string }) {
	if (event.source !== "interactive" || /^\s*\//.test(event.text) || event.text.trim() === "") return { action: "continue" as const };
	return { action: "transform" as const, text: stamp(event.text) };
}

// heredoc-guard (src chores ticket 14, moved here unchanged): refuse a bash tool
// call when a heredoc's delimiter is not a plain name, or its delimiter line
// appears more than once in the command.
//
// Bash ends a heredoc at the first line that is exactly its delimiter (after
// leading tabs are removed, under <<-). A body that quotes text holding the
// same delimiter, such as a test fixture, closes early, and bash runs the rest
// of the body as shell. On 13 Nov a worker's `python3 - <<'EOF'` did so and
// ran pw, tee and zfs lines in a jail where doas asks no password.
//
// Every operator in the command counts, wherever it stands: one inside a
// heredoc body or a quoted string counts too, which can only refuse more. A
// delimiter shared by two heredocs appears on two lines and is refused. The
// command is checked twice, as written and with its line continuations
// (backslash-newline) joined, since bash joins them in an operator's word and
// in the lines of a heredoc whose delimiter is unquoted. The joined pass also
// joins them in a quoted heredoc's body, where bash keeps them, and so may
// refuse a command bash would run: the user's deliberate choice, as is every
// `<<` counting (chores ticket 14's Comments).
//
// Only a plain delimiter passes: a name, [A-Za-z_][A-Za-z0-9_]*, bare or
// wholly in single or double quotes. Any other word is refused, since bash may
// read it otherwise than it looks: it decodes $'\x45OF' to EOF, and takes
// $(printf EOF), $((1)), ${x:-a b} or `echo EOF`, blanks and all, as the
// literal delimiter, where a simpler reading would stop early.

// `<<` not part of `<<<` (a here-string), an optional `-`, blanks, then a word:
// unquoted characters other than bash's blanks (space, tab), newline and shell
// metacharacters, backslash escapes, and quoted runs. The word ends only where
// bash's does, so a carriage return or any other character stays in it and
// makes it not plain. A word cut short here is still not plain.
const OPERATOR = /(?<!<)<<(?!<)(-?)[ \t]*((?:[^ \t\n;&|<>()'"\\]|\\[^\n]|'[^']*'|"(?:[^"\\]|\\[^])*")+)/g;

// A plain delimiter word; the name is its first, second or third group.
const PLAIN = /^(?:([A-Za-z_][A-Za-z0-9_]*)|'([A-Za-z_][A-Za-z0-9_]*)'|"([A-Za-z_][A-Za-z0-9_]*)")$/;

const ADVICE =
	"Edit files with the edit or write tool, not a heredoc. For a heredoc you need, such as a commit message, " +
	"choose a delimiter that appears on no other line, and give each heredoc its own. " +
	"Every `<<` counts, in a string or a heredoc body too: a commit message that quotes heredocs goes in a file, " +
	"written with the write tool, then `git commit -F <file>`.";

// A line's text, and the number of the line of the command as written where it ends.
type Line = { text: string; at: number };

/** Why the command is refused, or undefined to let it through. */
export function refusal(command: string): string | undefined {
	const written = command.split("\n").map((text, i) => ({ text, at: i + 1 }));
	return check(written, "") ?? check(joined(written), " of the command as written, once its line continuations are joined");
}

// The lines with every backslash-newline joined.
function joined(written: Line[]): Line[] {
	const lines: Line[] = [];
	let head = "";
	for (const { text, at } of written) {
		if (text.endsWith("\\") && at < written.length) head += text.slice(0, -1);
		else {
			lines.push({ text: head + text, at });
			head = "";
		}
	}
	return lines;
}

function check(lines: Line[], how: string): string | undefined {
	const command = lines.map((line) => line.text).join("\n");
	for (const [, dash, word] of command.matchAll(OPERATOR)) {
		const plain = PLAIN.exec(word);
		if (!plain) {
			return (
				`heredoc-guard: refused. The heredoc delimiter word \`${word}\` is not a plain name, and bash may read it ` +
				"otherwise than it looks (quotes, escapes, expansions), so a line that does not look like it may end the heredoc. " +
				`Use a plain delimiter: a name such as EOF, bare or wholly in single or double quotes. ${ADVICE}`
			);
		}
		const delimiter = plain[1] ?? plain[2] ?? plain[3];
		const at = lines.flatMap(({ text, at }) => ((dash ? text.replace(/^\t+/, "") : text) === delimiter ? [at] : []));
		if (at.length > 1) {
			return (
				`heredoc-guard: refused. The heredoc delimiter \`${delimiter}\` is a line of its own ${at.length} times in this command ` +
				`(lines ${at.join(", ")}${how}), so bash would end the heredoc at the first and run the lines after it as shell. ${ADVICE}`
			);
		}
	}
	return undefined;
}

export function heredocGuard(event: ToolCallEvent): ToolCallEventResult | undefined {
	if (event.toolName !== "bash") return undefined;
	const command = (event.input as { command?: unknown }).command;
	if (typeof command !== "string") return undefined;
	const reason = refusal(command);
	return reason === undefined ? undefined : { block: true, reason };
}

export default function guards(pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => siblingGuard(event, ctx));
	pi.on("tool_call", async (event) => heredocGuard(event));
	pi.on("input", async (event) => timeStamp(event));
}
