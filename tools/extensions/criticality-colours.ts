// Colour the criticality lines that /open-questions prints (tools/prompts/
// open-questions.md): a line of an assistant reply starting with 🔴, 🟠 or 🟡
// shows the rest of its text in red, orange or yellow; backticks on such a
// line are dropped, since pi's code styling would end the colour. Display only: pi's
// Markdown transformer leaves the session and the model's context unchanged
// (pi docs, extensions.md, registerMarkdownTransformer). Installed by
// install.mjs beside guards.ts.
const colours: Record<string, string> = {
	"🔴": "\x1b[38;5;196m", // high
	"🟠": "\x1b[38;5;208m", // medium
	"🟡": "\x1b[38;5;220m", // low
};
const line = /^(\s*)(🔴|🟠|🟡)(.*)$/gmu;

export default function (pi: { registerMarkdownTransformer: Function }) {
	pi.registerMarkdownTransformer(
		(markdown: string) =>
			markdown.replace(line, (_m: string, indent: string, dot: string, rest: string) => `${indent}${dot}${colours[dot]}${rest.replaceAll("`", "")}\x1b[39m`),
		{ messageTypes: ["assistant"] },
	);
}
