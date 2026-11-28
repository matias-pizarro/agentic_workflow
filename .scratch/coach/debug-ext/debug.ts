// Debug only (CS-Q121 live check): what a session sees of itself at each event.
import { appendFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function debug(pi: ExtensionAPI) {
	const log = (ev: string, ctx: any) => {
		let header: unknown;
		try { header = ctx.sessionManager.getHeader(); } catch (e) { header = `throws ${(e as Error).message}`; }
		appendFileSync(process.env.DEBUG_LOG ?? "/dev/null", JSON.stringify({ ev, file: ctx.sessionManager.getSessionFile(), header, child: process.env.PI_SUBAGENT_CHILD ?? null }) + "\n");
	};
	pi.on("session_start", async (_e, ctx) => log("session_start", ctx));
	pi.on("agent_settled", async (_e, ctx) => log("agent_settled", ctx));
	pi.on("session_shutdown", async (_e, ctx) => log("session_shutdown", ctx));
}
