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
		return writes ? { block: true, reason: SIBLING_REFUSAL } : undefined;
	}
	return undefined;
}

export default function guards(pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => siblingGuard(event, ctx));
}
