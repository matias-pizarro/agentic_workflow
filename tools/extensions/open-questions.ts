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
// - The seat's tmux window tab is coloured from the last STATUS line of each
//   turn (rules.md, Team mechanics; PA-Q52, the user, 16 Nov): open=0 green;
//   open above 0 red, orange or yellow by worst= (yellow without it); a turn
//   without a STATUS line, or without open=, leaves it as it is. The tab also
//   turns green once the operator types in the pane (not a "Lead:" message,
//   not a /command), until the seat's next STATUS line says otherwise.
// - While open= is above 0, the window carries @open=<n>, which the tab format
//   in tmux.conf shows as " [n]" after the name (the user, 17 Nov).
// - While the last STATUS line says state=waiting-for-PM, the window carries
//   @todo, which the tab format in tmux.conf shows as " ✋" after the name: the
//   seat waits on the operator (AW-Q99, the user, 19 Nov 14:42). Cleared like the green tab: by the seat's next STATUS line
//   saying another state, or once the operator types in the pane.
// - A turn whose last STATUS line says state=waiting-for-PM with open=0 gets a
//   warning in the pane: every step the seat waits on the operator for is an
//   open question (rules.md rule 4; AW-Q140, the user, 20 Nov 10:35).
// - While the last STATUS line says state=ready-for-lead or waiting-for-seat,
//   the window carries @wait, which the tab format in tmux.conf shows as " ⏳"
//   after the name: the seat waits on the team, not on the operator (AW-Q118,
//   the user, 19 Nov 22:07). Cleared by the seat's next STATUS line saying
//   another state.
// - While the agent works, its window carries the tmux option @working, which
//   the tab format in tmux.conf shows as ⚡ after the name (the user, 16 Nov).
// - At the end of each turn, each new "❓ <ID>" of the reply (an -Q ID, as
//   team.sh report registers) is registered to this seat, its tmux window's
//   name, in the question-ID registry whose path team.sh puts in the tmux
//   server option @team-qids, under team.sh's lock; an ID another seat holds is
//   noticed in the pane (RT3-Q9), and so is a turn whose IDs it cannot register.
// - Every full path to an existing Markdown file in a reply gets its md-html
//   page (AW-Q135, the user, 20 Nov 00:00): the pane lists the pages before the
//   reply's STATUS line, display only, and the end of the turn runs md-html,
//   the one beside team.sh, on those files; a failure is noticed in the pane.
// - A reload_runtime tool, so a seat reloads its own extensions when the lead
//   or the operator says so (RT3-Q5): it ends the turn, then runs
//   /reload-runtime once the agent has settled (pi docs, extensions.md).
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync, appendFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
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
// A question ID: a prefix, then -Q<n> for a question or -A<n> for an assumption
// awaiting confirmation (VW-A3), e.g. AW-Q3, NET-Q6b, CHK-net-Q1.
const QUESTION = /❓\s*\**\s*([A-Z][A-Za-z0-9-]*-[QA][0-9]+[a-z]?)/u;
// What team.sh report registers: -Q IDs only.
const REGISTERED = /❓ *\** *([A-Z][A-Za-z0-9-]*-Q[0-9]+[a-z]?)/gu;
// A message team.sh types ("Lead: ...") or a /command, after guards.ts's time stamp if any.
const NOT_TYPED_BY_OPERATOR = /^\s*(?:\[\d{1,2} [A-Z][a-z]{2} \d{2}:\d{2}\]\s*)?(Lead:|\/)/;
const TABS: Record<string, string> = {
	high: "bg=colour88,fg=colour254",
	medium: "bg=colour208,fg=black",
	low: "bg=colour220,fg=black",
	green: "bg=colour34,fg=black",
};
// A whole STATUS line, its fields in their fixed order from the line's start
// (SOCR-Q1): a quoted example or an ask="... open=1 ..." text does not count.
const STATUS_LINE = /^\s*`?STATUS seat=\S+ state=(\S+) open=(\d+)(?: worst=(high|medium|low))?(?=[\s`]|$)/gmu;

// The tab's colour a reply's last STATUS line asks for: "green" at open=0,
// its worst= ("low" without one) above 0, or undefined to leave the tab as is.
export function tabFor(reply: string): string | undefined {
	const open = openFor(reply);
	if (open === undefined) return undefined;
	if (open === 0) return "green";
	return [...reply.matchAll(STATUS_LINE)].at(-1)![3] ?? "low";
}

// The open= count of a reply's last STATUS line, or undefined without one.
export function openFor(reply: string): number | undefined {
	const last = [...reply.matchAll(STATUS_LINE)].at(-1);
	return last ? Number(last[2]) : undefined;
}

// Whether a reply's last STATUS line says the seat waits on the operator, or
// undefined without one.
export function todoFor(reply: string): boolean | undefined {
	const last = [...reply.matchAll(STATUS_LINE)].at(-1);
	return last ? last[1] === "waiting-for-PM" : undefined;
}

// Whether a reply's last STATUS line says waiting-for-PM with open=0: a wait
// on the operator not asked as a question (AW-Q140).
export function unaskedWait(reply: string): boolean {
	return todoFor(reply) === true && openFor(reply) === 0;
}

// Whether a reply's last STATUS line says the seat waits on the team (the lead
// or another seat), or undefined without one.
export function waitFor(reply: string): boolean | undefined {
	const last = [...reply.matchAll(STATUS_LINE)].at(-1);
	return last ? last[1] === "ready-for-lead" || last[1] === "waiting-for-seat" : undefined;
}

// The tab's ⏳ after the name: the window option @wait (AW-Q118).
function showWait(on: boolean) {
	if (on) setWindowOption([], "@wait", "1");
	else setWindowOption(["-u"], "@wait");
}

// The tab's ✋ after the name: the window option @todo, shown by the tab
// format in tmux.conf (AW-Q99).
function showTodo(on: boolean) {
	if (on) setWindowOption([], "@todo", "1");
	else setWindowOption(["-u"], "@todo");
}

// The tab's [n] after the name: the window option @open, shown by the tab
// format in tmux.conf; unset at 0 (the user, 17 Nov).
function showOpen(n: number) {
	if (n > 0) setWindowOption([], "@open", String(n));
	else setWindowOption(["-u"], "@open");
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

// The registry's lines for the reply's new IDs, and the IDs other seats hold:
// registry lines are "ID<TAB>seat<TAB>date".
export function claimIds(reply: string, seat: string, registry: string, date: string) {
	const owners = new Map(registry.split("\n").filter(Boolean).map((line) => {
		const [id, owner, when] = line.split("\t");
		return [id, { owner, when }] as const;
	}));
	const lines: string[] = [];
	const taken: string[] = [];
	for (const id of new Set([...reply.matchAll(REGISTERED)].map((m) => m[1]))) {
		const held = owners.get(id);
		if (!held) lines.push(`${id}\t${seat}\t${date}`);
		else if (held.owner !== seat) taken.push(`❓ ${id} is ${held.owner}'s (${held.when})`);
	}
	return { lines, taken };
}

function tmuxOut(args: string[]): string | undefined {
	if (!process.env.TMUX) return undefined;
	const r = spawnSync("tmux", args, { encoding: "utf8" });
	return r.status === 0 && r.stdout.trim() ? r.stdout.trim() : undefined;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const pause = (ms: number) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

// team.sh's lock: a directory holding the owner's pid; one whose owner is gone is removed.
function withLock(dir: string, body: () => void): boolean {
	for (let i = 0; i < 50; i++) {
		try {
			mkdirSync(dir);
		} catch {
			let owner = NaN;
			try {
				owner = Number(readFileSync(`${dir}/pid`, "utf8"));
				process.kill(owner, 0);
			} catch {
				if (!Number.isNaN(owner)) rmSync(dir, { recursive: true, force: true });
			}
			pause(100);
			continue;
		}
		try {
			writeFileSync(`${dir}/pid`, `${process.pid}\n`);
			body();
		} finally {
			rmSync(dir, { recursive: true, force: true });
		}
		return true;
	}
	return false;
}

// Register the reply's new IDs; a sentence for the pane when something went wrong or is taken.
function registerIds(reply: string): string | undefined {
	if (!reply.includes("❓")) return undefined;
	const path = tmuxOut(["show", "-gv", "@team-qids"]);
	const pane = process.env.TMUX_PANE;
	const seat = pane ? tmuxOut(["display", "-p", "-t", pane, "#{window_name}"]) : undefined;
	if (!path) return "question IDs not registered: no registry path (tmux option @team-qids); it is set at the next team.sh send, report, spawn or revive";
	if (!seat) return "question IDs not registered: this pane's tmux window name cannot be read";
	const now = new Date();
	const date = `${now.getDate()} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
	let taken: string[] = [];
	let failure: string | undefined;
	const locked = withLock(`${path}.lock`, () => {
		let registry = "";
		try {
			registry = readFileSync(path, "utf8");
		} catch (e) {
			if ((e as NodeJS.ErrnoException).code !== "ENOENT") {
				failure = `cannot read ${path}`;
				return;
			}
		}
		const claim = claimIds(reply, seat, registry, date);
		if (claim.lines.length) appendFileSync(path, `${claim.lines.join("\n")}\n`);
		taken = claim.taken;
	});
	if (!locked) return `question IDs not registered: cannot lock ${path}.lock`;
	if (failure) return `question IDs not registered: ${failure}`;
	if (taken.length) return `${taken.join("; ")}: renumber yours (rules.md rule 4)`;
	return undefined;
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

// Pages for the Markdown a reply names (AW-Q135, the user, 20 Nov 00:00): every
// full path to an existing .md or .markdown file gets its md-html page, made at
// the end of the turn, and the pane lists the pages under the reply. md-html is
// the one beside team.sh (the tmux option @team-sh); its pages go under
// <root>/html/, mirroring the Markdown's full path, as md-html writes them.
const MD_PATH = /(?<![\w./-])\/[^\s`'"<>()[\]{}|*]+\.(?:md|markdown)(?![\w-]|\.\w)/gu;

// The full paths to existing Markdown files a text names, each once, in order.
const isFile = (p: string) => {
	try {
		return statSync(p).isFile();
	} catch {
		return false;
	}
};
export function mdPaths(text: string, exists: (p: string) => boolean = isFile): string[] {
	return [...new Set(text.match(MD_PATH) ?? [])].filter((p) => exists(p));
}

// The page md-html writes for a Markdown file, given md-html's own path.
export function pageFor(md: string, mdHtml: string): string {
	return join(resolve(dirname(mdHtml), "..", ".."), "html", `${md.replace(/\.(md|markdown)$/i, "")}.html`);
}

// The reply as the pane shows it, with a "Pages" list before its STATUS line
// (or at its end): one page per Markdown path, each on its own line.
export function withPages(markdown: string, pages: string[]): string {
	if (pages.length === 0) return markdown;
	const block = `Pages to open in a browser:\n${pages.map((p) => `- ${p}`).join("\n")}\n`;
	const lines = markdown.split("\n");
	const status = /^\s*`?STATUS seat=\S+ state=\S+ open=\d+/;
	for (let at = lines.length - 1; at >= 0; at--) {
		if (status.test(lines[at])) {
			lines.splice(at, 0, block);
			return lines.join("\n");
		}
	}
	return `${markdown.replace(/\s*$/, "")}\n\n${block}`;
}

let mdHtmlPath: string | undefined;
let mdHtmlTried = 0;
// md-html beside team.sh, or null outside the team's tmux server. Found once,
// then kept; until found, looked up again at most every 30 s, since team.sh
// sets @team-sh at its next send, report, spawn or revive.
function mdHtml(): string | null {
	if (mdHtmlPath) return mdHtmlPath;
	if (Date.now() - mdHtmlTried < 30_000) return null;
	mdHtmlTried = Date.now();
	const teamSh = tmuxOut(["show", "-gv", "@team-sh"]);
	if (!teamSh) return null;
	try {
		const p = join(dirname(realpathSync(teamSh)), "md-html");
		if (existsSync(p)) mdHtmlPath = p;
	} catch {
		// team.sh unreadable: no pages this time
	}
	return mdHtmlPath ?? null;
}

// Make the pages of the Markdown a reply names; a sentence for the pane on failure.
function makePages(reply: string): string | undefined {
	const files = mdPaths(reply);
	const tool = mdHtml();
	if (files.length === 0 || !tool) return undefined;
	const r = spawnSync(tool, files, { encoding: "utf8", timeout: 60_000 });
	if (r.status === 0) return undefined;
	const why = (r.stderr || r.error?.message || `exit ${r.status}`).trim().split("\n").slice(-1)[0];
	return `md-html pages not made: ${why}`;
}

export default function openQuestions(pi: ExtensionAPI) {
	pi.registerMarkdownTransformer(
		(markdown: string) => {
			const tool = mdHtml();
			const pages = tool ? mdPaths(markdown).map((md) => pageFor(md, tool)) : [];
			return withPages(markdown, pages)
				.replace(MARKED_LINE, (_m: string, indent: string, dot: string, rest: string) =>
					`${indent}${dot}${COLOURS[dot]}${rest.replaceAll("`", "")}${FG_RESET}`,
				)
				.replace(NONE_LINE, (_m: string, indent: string, lead: string) => `${indent}${GREEN}${lead}NONE${FG_RESET}`)
				.replace(NO_QUESTIONS_LINE, (_m: string, indent: string, text: string) => `${indent}${GREEN}${text}${FG_RESET}`);
		},
		{ messageTypes: ["assistant"] },
	);

	let asked = false;
	pi.on("input", async (event) => {
		if (event.source === "interactive" && !NOT_TYPED_BY_OPERATOR.test(event.text)) {
			colourTab("green");
			showOpen(0);
			showTodo(false);
		}
		if (/^\s*\/o\s*$/.test(event.text)) {
			asked = true;
			return { action: "transform", text: "/open-questions" };
		}
		if (/^\s*\/open-questions\b/.test(event.text)) asked = true;
		return { action: "continue" };
	});

	pi.on("agent_start", async () => markWorking(true));

	pi.registerCommand("reload-runtime", {
		description: "Reload extensions, skills, prompts, themes, and context files",
		handler: async (_args, ctx) => {
			await ctx.reload();
			return;
		},
	});
	let reloadRequested = false;
	pi.registerTool({
		name: "reload_runtime",
		label: "Reload Runtime",
		description:
			"Reload this pi session's extensions, skills, prompts, themes and context files, after this turn. " +
			"Use it only when the lead or the operator asks you to reload.",
		parameters: { type: "object", properties: {} } as never,
		async execute() {
			reloadRequested = true;
			return { content: [{ type: "text", text: "Reload requested. Pi reloads after this response." }], details: {}, terminate: true };
		},
	});
	pi.on("agent_settled", async () => {
		if (!reloadRequested) return;
		reloadRequested = false;
		pi.sendUserMessage("/reload-runtime", { expandPromptTemplates: true });
	});

	pi.on("agent_settled", async (event, ctx) => {
		markWorking(false);
		if (!event.aborted) {
			const reply = lastAssistantText(ctx) ?? "";
			const tab = tabFor(reply);
			if (tab) colourTab(tab);
			const open = openFor(reply);
			if (open !== undefined) showOpen(open);
			const todo = todoFor(reply);
			if (todo !== undefined) showTodo(todo);
			const wait = waitFor(reply);
			if (wait !== undefined) showWait(wait);
			if (unaskedWait(reply) && ctx.hasUI)
				ctx.ui.notify("STATUS says waiting-for-PM with open=0: ask what you wait on the operator for as a question, counted in open (rules.md rule 4)", "warning");
			const notice = registerIds(reply);
			if (notice && ctx.hasUI) ctx.ui.notify(notice, "warning");
			const pageNotice = makePages(reply);
			if (pageNotice && ctx.hasUI) ctx.ui.notify(pageNotice, "warning");
		}
		if (!asked) return;
		asked = false;
		if (event.aborted || !ctx.hasUI || ctx.ui.getEditorText().trim() !== "") return;
		const rows = answerRows(lastAssistantText(ctx) ?? "");
		if (rows.length > 0) ctx.ui.setEditorText(rows.join("\n"));
	});
}
