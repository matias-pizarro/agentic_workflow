// Drive the heredoc guard's tool_call handler as Pi does, for one tool call.
//
// Usage: node verdict.mjs <extension> <tool> <command file>
//
// Exit 0, the reason on stdout: the call is refused. Exit 1: let through.
// Exit 2: the extension failed to load or to answer.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

try {
	const [extension, toolName, file] = process.argv.slice(2);
	if (!file) throw new Error("usage: node verdict.mjs <extension> <tool> <command file>");
	const handlers = [];
	const pi = { on: (event, handler) => event === "tool_call" && handlers.push(handler) };
	(await import(pathToFileURL(extension).href)).default(pi);
	if (handlers.length !== 1) throw new Error(`expected one tool_call handler, got ${handlers.length}`);
	const event = { type: "tool_call", toolCallId: "t1", toolName, input: { command: readFileSync(file, "utf8") } };
	const result = await handlers[0](event, {});
	if (result?.block === true) {
		console.log(result.reason);
		process.exit(0);
	}
	if (result !== undefined) throw new Error(`unexpected result ${JSON.stringify(result)}`);
	process.exit(1);
} catch (error) {
	console.error(`verdict.mjs: ${error?.stack ?? error}`);
	process.exit(2);
}
