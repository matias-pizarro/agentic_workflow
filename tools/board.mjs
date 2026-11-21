#!/usr/bin/env node
// The team board (.scratch/team-board/perimeter.md, TB-Q1 to TB-Q17): a
// full-screen table of the seats and one of their tasks, redrawn as they
// change. Read-only: it writes nothing, anywhere.
//
//   board.mjs          split this tmux pane side by side: seats here, tasks on
//                      the right (TB-Q6); Ctrl-C closes both
//   board.mjs seats    the seats table only
//   board.mjs tasks    the tasks table only
//   board.mjs open     start the board in window 0 of the lead's tmux session, the
//                      other windows moving up one, unless a window named
//                      board exists; team.sh revive --all runs it (TB-Q20, TB-Q29)
//
// Seats (TB-Q1 to TB-Q5, TB-Q16): every seat recorded in team.sh's registry
// (tools/agents) that has a tmux window, and the lead (the pane with
// @role=lead). Each seat's fields are the window options open-questions.ts
// publishes at each turn's end (@state, @for, @open, @worst, @ask, @ctx,
// @working, @todo, @wait); a window without @state is read from its pane's
// last STATUS line instead. Waiting-for is @for, else derived from the state
// (PM, lead, or the first seat named in ask=). "Created" is the seat's spawn
// line in the ledger, else its earliest line; "refreshed" the first start
// line of its current session.
// Tasks (TB-Q7 to TB-Q11): the undone tasks of a Vikunja project that have a
// live seat (a seat:<name> label, else a title ending in "(<name>)"), plus
// those outside the Backlog bucket; worst status first, then by #. Read by
// GET on Vikunja's REST API every 60 s; a failed read keeps the last table.
//
// Environment: TEAM_AGENTS and TEAM_LEDGER override the registry and the
// ledger (default: beside the team.sh named by the tmux option @team-sh, and
// the option @team-ledger). VIKUNJA_URL and VIKUNJA_PROJECT (its id) enable
// the tasks table; VIKUNJA_TOKEN_FILE names the token file, read at each
// fetch (default: the sandbox bot's, ~/.config/sandbox/vikunja-agents-jail.token,
// TB-Q11, TB-Q28). External text (titles, ask=) is drawn with its control
// characters removed (TB-Q21), and long rows are clipped at the pane's edge
// (TB-Q22). A variable not in the environment is read from board.conf beside
// the registry, one KEY=value per line, for a board reopened by revive, which
// has no operator's shell to inherit from. TEAM_TMUX names a separate tmux
// server (tmux -L), as for team.sh. Seats are polled every 2 s; the screen is redrawn when anything
// changed, and each minute for the times.
//
// Keys (TB-Q14, TB-Q15), in each table: ↑ ↓ select a row; < > move the sort
// column, s reverses it; / filters the rows by text (Enter keeps it, Esc
// clears it); Ctrl-C quits. In the seats table, r refreshes and R retires the
// selected seat, after a typed y, through team.sh refresh <seat> "board: r
// <seat>" "board pane hh:mm" and team.sh retire <seat>; R does nothing on the
// lead, and retire never passes --no-checkout.
import { spawnSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SEP = "\x1f";

function tmux(args) {
	const server = process.env.TEAM_TMUX ? ["-L", process.env.TEAM_TMUX] : [];
	const r = spawnSync("tmux", [...server, ...args], { encoding: "utf8" });
	return r.status === 0 ? r.stdout : undefined;
}

// --- data: the seats -------------------------------------------------------

const STATUS_LINE = /^[ \t]*`?STATUS seat=\S+ state=(\S+)(?: for=(\S+))? open=(\d+)(?: worst=(high|medium|low))?(?=[\s`]|$)/gmu;

// The last STATUS line in a pane's text, as the fields the options carry.
export function scrapeStatus(text) {
	const last = [...text.matchAll(STATUS_LINE)].at(-1);
	if (!last) return undefined;
	const line = text.slice(last.index).split("\n")[0];
	return { state: last[1], for: last[2] ?? "", open: last[3], worst: last[4] ?? "", ask: line.match(/ ask="([^"]*)"?/u)?.[1] ?? "" };
}

// Who a seat waits for: its for= field, else derived from its state (TB-Q2 (a), TB-Q3).
export function waitingFor(state, forField, ask, seatNames) {
	if (forField) return forField;
	if (state === "waiting-for-PM") return "PM";
	if (state === "ready-for-lead") return "lead";
	if (state === "waiting-for-seat") {
		const words = (ask ?? "").split(/[^A-Za-z0-9._-]+/).map((w) => w.replace(/\.+$/, ""));
		return words.find((w) => seatNames.includes(w)) ?? "seat?";
	}
	return "";
}

// The ledger's lines as [time ms, event, seat, session id].
export function parseLedger(text) {
	return text.split("\n").filter(Boolean).map((line) => {
		const [stamp, event, seat, id] = line.split("\t");
		const m = stamp?.match(/^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/);
		const at = m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() : NaN;
		return { at, event, seat, id };
	}).filter((l) => !Number.isNaN(l.at));
}

// When a seat was created and when its current session started (TB-Q5).
export function seatTimes(ledger, seat, sessionId) {
	const mine = ledger.filter((l) => l.seat === seat);
	const created = (mine.find((l) => l.event === "spawn") ?? mine[0])?.at;
	const refreshed = sessionId ? mine.find((l) => l.event === "start" && l.id === sessionId)?.at : undefined;
	return { created, refreshed };
}

// "2d 3h 15m", the days only when above 0 (TB-Q5); "?" when unknown.
export function since(at, now) {
	if (at === undefined || Number.isNaN(at)) return "?";
	const m = Math.max(0, Math.floor((now - at) / 60000));
	const d = Math.floor(m / 1440);
	const h = Math.floor((m % 1440) / 60);
	return `${d > 0 ? `${d}d ` : ""}${h}h ${m % 60}m`;
}

function teamPaths() {
	const teamSh = tmux(["show", "-gv", "@team-sh"])?.trim();
	const agents = process.env.TEAM_AGENTS ?? (teamSh ? join(dirname(teamSh), "agents") : undefined);
	const ledger = process.env.TEAM_LEDGER ?? tmux(["show", "-gv", "@team-ledger"])?.trim();
	return { agents, ledger };
}

function readOr(path, fallback) {
	try {
		return readFileSync(path, "utf8");
	} catch {
		return fallback;
	}
}
function stamp(path) {
	try {
		const s = statSync(path);
		return `${s.mtimeMs}:${s.size}`;
	} catch {
		return "absent";
	}
}

const WINDOW_FORMAT = ["window_index", "window_name", "@state", "@for", "@open", "@worst", "@ask", "@ctx", "@working", "@todo", "@wait"]
	.map((f) => `#{${f}}`).join(SEP);

const capture = (target) => tmux(["capture-pane", "-p", "-J", "-S", "-2000", "-t", target]) ?? "";

// The raw reads one poll makes; their text is also the poll's change
// signature, with the panes scraped because they publish nothing yet (TB-Q26).
function readSeatsRaw() {
	const { agents, ledger } = teamPaths();
	const windows = tmux(["list-windows", "-F", WINDOW_FORMAT]);
	const panes = tmux(["list-panes", "-s", "-F", ["#{window_index}", "#{@role}", "#{@session-id}", "#{pane_id}"].join(SEP)]);
	const scraped = new Map();
	const lead = (panes ?? "").split("\n").map((l) => l.split(SEP)).find((p) => p[1] === "lead");
	for (const line of (windows ?? "").split("\n").filter(Boolean)) {
		const [idx, , state, , , , , ctx] = line.split(SEP);
		if (state && ctx) continue;
		scraped.set(idx, capture(lead && lead[0] === idx ? lead[3] : idx));
	}
	const scrapedSig = [...scraped].map(([i, t]) => `${i}:${[...t.matchAll(STATUS_LINE)].at(-1)?.[0] ?? ""}`).join(",");
	return { agents, ledger, windows, panes, scraped, sig: `${windows}|${panes}|${stamp(agents)}|${stamp(ledger)}|${scrapedSig}` };
}

export function buildSeats(raw, now, scrape = (idx) => raw.scraped?.get(idx) ?? "") {
	const registry = readOr(raw.agents, "").split("\n").filter(Boolean).map((l) => l.split("\t"));
	const ledger = parseLedger(readOr(raw.ledger, ""));
	const leadPane = (raw.panes ?? "").split("\n").map((l) => l.split(SEP)).find((p) => p[1] === "lead");
	const names = [...registry.map((r) => r[0]), "lead"];
	const rows = [];
	for (const line of (raw.windows ?? "").split("\n").filter(Boolean)) {
		const [idx, name, state, forField, open, worst, ask, ctx, working, todo, wait] = line.split(SEP);
		const isLead = leadPane && leadPane[0] === idx;
		const rec = registry.find((r) => r[0] === name);
		if (!isLead && !rec) continue;
		const seat = isLead ? "lead" : name;
		let f = { state, for: forField, open: open || (state ? "0" : ""), worst, ask };
		let percent = ctx;
		if (!state || !ctx) {
			// Not published yet (no turn ended since the extension loaded): the pane's last STATUS line and pi's footer.
			const text = scrape(idx);
			if (!state) f = scrapeStatus(text) ?? { state: "", for: "", open: "", worst: "", ask: "" };
			if (!ctx) percent = [...text.matchAll(/(\d+(?:\.\d+)?)%\/\d/g)].at(-1)?.[1] ?? "";
		}
		const { created, refreshed } = seatTimes(ledger, seat, isLead ? leadPane[2] : rec[3]);
		rows.push({
			seat,
			icon: working ? "⚡" : todo ? "✋" : wait ? "⏳" : "",
			ctx: percent ? `${Math.round(Number(percent))}%` : "?",
			state: f.state || "?",
			open: f.open === "" ? "?" : f.open,
			worst: f.worst,
			for: waitingFor(f.state, f.for, f.ask, names),
			created: since(created, now),
			refreshed: since(refreshed, now),
			createdAt: created,
			refreshedAt: refreshed,
			ask: f.ask,
		});
	}
	return rows;
}

// --- data: the tasks -------------------------------------------------------

// A seat state's task status and its rank, worst highest (TB-Q8, TB-Q9).
const TASK_STATUS = {
	idle: "idle", done: "idle", working: "working",
	"waiting-for-seat": "waiting for seat", "ready-for-lead": "waiting for seat",
	blocked: "blocked", "waiting-for-PM": "waiting for PM",
};
// "?": a seat whose state cannot be read yet, ranked with idle.
const RANK = { "pending seat": 0, "?": 1, idle: 1, working: 2, "waiting for seat": 3, blocked: 4, "waiting for PM": 5 };

// The seats a task involves: its seat:<name> labels, else the name its title ends with in brackets (TB-Q7).
export function taskSeats(task) {
	const labelled = (task.labels ?? []).map((l) => l.title).filter((t) => t.startsWith("seat:")).map((t) => t.slice(5));
	if (labelled.length) return labelled;
	const m = task.title.match(/\(([A-Za-z0-9._-]+)\)\s*$/);
	return m ? [m[1]] : [];
}

export function buildTasks(tasks, outsideBacklog, seats, baseUrl) {
	const live = new Map(seats.map((s) => [s.seat, s]));
	const rows = [];
	for (const t of tasks) {
		const names = taskSeats(t);
		const mine = names.filter((n) => live.has(n)).map((n) => live.get(n));
		if (!mine.length && !outsideBacklog.has(t.id)) continue;
		const status = mine.length
			? mine.map((s) => TASK_STATUS[s.state] ?? "?").reduce((a, b) => (RANK[b] > RANK[a] ? b : a))
			: "pending seat";
		rows.push({
			index: t.index,
			id: t.id,
			name: t.title,
			tier: (t.labels ?? []).map((l) => l.title).find((x) => x.startsWith("tier:"))?.slice(5) ?? "",
			link: `${baseUrl}/tasks/${t.id}`,
			seats: names.join(","),
			status,
			open: mine.reduce((n, s) => n + (Number(s.open) || 0), 0),
			blockedBy: (t.related_tasks?.blocked ?? []).map((b) => `#${b.index}`).join(","),
		});
	}
	return rows;
}

const tokenFile = () => process.env.VIKUNJA_TOKEN_FILE || join(homedir(), ".config/sandbox/vikunja-agents-jail.token");

async function vikunja(path) {
	const token = readFileSync(tokenFile(), "utf8").trim();
	const r = await fetch(`${process.env.VIKUNJA_URL}/api/v1${path}`, { headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(20000) });
	if (!r.ok) throw new Error(`GET ${path}: HTTP ${r.status}`);
	return { body: await r.json(), pages: Number(r.headers.get("x-pagination-total-pages") ?? 1) };
}

// The project's undone tasks and the ids of those outside Backlog.
async function fetchTasks() {
	const p = process.env.VIKUNJA_PROJECT;
	const { body: views } = await vikunja(`/projects/${p}/views`);
	const list = views.find((v) => v.view_kind === "list");
	const kanban = views.find((v) => v.view_kind === "kanban");
	if (!list || !kanban) throw new Error("the project has no list or no kanban view");
	const tasks = [];
	for (let page = 1, pages = 1; page <= pages; page++) {
		const r = await vikunja(`/projects/${p}/views/${list.id}/tasks?filter=done%3Dfalse&per_page=50&page=${page}`);
		tasks.push(...r.body);
		pages = r.pages;
	}
	const { body: buckets } = await vikunja(`/projects/${p}/views/${kanban.id}/tasks?filter=done%3Dfalse`);
	const outside = new Set(buckets.filter((b) => b.title !== "Backlog").flatMap((b) => (b.tasks ?? []).map((t) => t.id)));
	return { tasks, outside };
}

// --- drawing ---------------------------------------------------------------

// Terminal columns of a string: emoji presentation counts 2, combining marks 0.
export function width(s) {
	let w = 0;
	for (const ch of s) {
		if (/\p{Mn}|️|‍/u.test(ch)) continue;
		w += /\p{Emoji_Presentation}/u.test(ch) ? 2 : 1;
	}
	return w;
}
// External text without control characters (C0, DEL, C1): no escape sequence
// or line break of a title or an ask= reaches the terminal (TB-Q21).
export const clean = (s) => String(s ?? "").replace(/[\u0000-\u001f\u007f-\u009f]/g, " ");
export function fit(s, n) {
	s = clean(s);
	if (width(s) <= n) return s + " ".repeat(n - width(s));
	let out = "";
	for (const ch of s) {
		if (width(out + ch) > n - 1) break;
		out += ch;
	}
	return out + "…" + " ".repeat(Math.max(0, n - 1 - width(out)));
}

const COLOUR = { high: "\x1b[38;5;196m", medium: "\x1b[38;5;208m", low: "\x1b[38;5;220m", green: "\x1b[38;5;40m", grey: "\x1b[38;5;244m", fg: "\x1b[39m", bold: "\x1b[1m", reverse: "\x1b[7m", reset: "\x1b[0m" };

// Lay out a table: fixed columns, and one flexible column taking what is
// left; the sort column's title marked ▲ or ▼, the selected row reversed.
export function table(cols, rows, totalWidth, view = {}) {
	const fixed = cols.filter((c) => !c.flex).reduce((n, c) => n + c.w + 1, 0);
	const flexW = Math.max(8, totalWidth - fixed);
	const w = (c) => (c.flex ? flexW : c.w);
	const title = (c, i) => (i === view.sort ? `${c.title}${view.desc ? "▼" : "▲"}` : c.title);
	const head = COLOUR.bold + cols.map((c, i) => fit(title(c, i), w(c))).join(" ") + COLOUR.reset;
	const body = rows.map((r, n) => {
		const line = cols.map((c) => {
			const cell = fit(r[c.key], w(c));
			const colour = c.colour?.(r);
			return colour ? colour + cell + COLOUR.fg : cell;
		}).join(" ");
		return n === view.selected ? COLOUR.reverse + line + COLOUR.reset : line;
	});
	return [head, ...body];
}

// The rows as shown (TB-Q15): those holding the filter's text in any column
// (case ignored), sorted by the sort column, ties by the first column.
export function arrange(rows, cols, view) {
	const col = cols[view.sort];
	const value = (r) => (col.sortValue ? col.sortValue(r) : r[col.key]);
	const compare = (x, y) => (typeof x === "number" && typeof y === "number" ? x - y : String(x ?? "").localeCompare(String(y ?? ""), undefined, { numeric: true }));
	const first = cols[0].key;
	const text = view.filter.toLowerCase();
	return rows
		.filter((r) => !text || cols.some((c) => clean(r[c.key]).toLowerCase().includes(text)))
		.sort((a, b) => (view.desc ? -1 : 1) * compare(value(a), value(b)) || compare(a[first], b[first]));
}

const SEAT_COLS = [
	{ key: "seat", title: "SEAT", w: 17 },
	{ key: "icon", title: "", w: 2 },
	{ key: "ctx", title: "CTX", w: 4, sortValue: (r) => parseFloat(r.ctx) || -1 },
	{ key: "state", title: "STATE", w: 16 },
	{ key: "open", title: "OPEN", w: 4, sortValue: (r) => Number(r.open) || 0, colour: (r) => (r.open === "0" ? COLOUR.green : COLOUR[r.worst || "low"]) },
	{ key: "for", title: "WAITING FOR", w: 16, flex: true },
	{ key: "created", title: "CREATED", w: 11, sortValue: (r) => r.createdAt ?? Infinity },
	{ key: "refreshed", title: "REFRESHED", w: 11, sortValue: (r) => r.refreshedAt ?? Infinity },
];
const TASK_COLS = [
	{ key: "index", title: "#", w: 3, sortValue: (r) => r.index },
	{ key: "id", title: "ID", w: 4, sortValue: (r) => r.id },
	{ key: "name", title: "NAME", w: 20, flex: true },
	{ key: "tier", title: "TIER", w: 9 },
	{ key: "link", title: "LINK", w: 34 },
	{ key: "seats", title: "SEATS", w: 16 },
	{ key: "status", title: "STATUS", w: 16, sortValue: (r) => RANK[r.status], colour: (r) => ({ "waiting for PM": COLOUR.high, blocked: COLOUR.medium, "waiting for seat": COLOUR.low, "pending seat": COLOUR.grey })[r.status] },
	{ key: "open", title: "OPEN", w: 4, sortValue: (r) => r.open },
	{ key: "blockedBy", title: "BLOCKED BY", w: 10 },
];

function hhmm(d) {
	return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

function draw(lines) {
	const rows = process.stdout.rows || 24;
	const out = lines.slice(0, rows).map((l) => `${l}\x1b[K`).join("\r\n");
	process.stdout.write(`\x1b[H${out}\x1b[J`);
}

function screen(onExit) {
	// Alternate screen, cursor hidden, autowrap off: a row wider than the pane is clipped (TB-Q22).
	process.stdout.write("\x1b[?1049h\x1b[?25l\x1b[?7l");
	const restore = () => {
		if (process.stdin.isTTY) process.stdin.setRawMode(false);
		process.stdout.write("\x1b[?7h\x1b[?25h\x1b[?1049l");
	};
	const quit = () => {
		restore();
		onExit?.();
		process.exit(0);
	};
	process.on("SIGINT", quit);
	process.on("SIGTERM", quit);
	process.on("SIGHUP", quit);
	process.on("SIGQUIT", quit);
}

// --- keys (TB-Q14, TB-Q15) ---------------------------------------------------

const HELP = "↑↓ select  < > sort  s reverse  / filter";

// A table's interactive state; the keys change it, then redraw.
function makeView(sort, desc) {
	return { sort, desc, filter: "", editing: false, selectedKey: undefined, prompt: undefined, message: "" };
}

// The selected row's index in the shown rows, keeping the selection on the same row's key.
function selectedIndex(view, shown, keyOf) {
	const i = shown.findIndex((r) => keyOf(r) === view.selectedKey);
	if (i >= 0) return i;
	view.selectedKey = shown.length ? keyOf(shown[0]) : undefined;
	return shown.length ? 0 : undefined;
}

// The line under the title: the filter being typed, a confirmation, the last action's outcome, or the keys.
function statusLine(view, help) {
	if (view.editing) return `filter: ${clean(view.filter)}_  (Enter keeps it, Esc clears it)`;
	if (view.prompt) return `${COLOUR.reverse}${clean(view.prompt.text)}${COLOUR.reset}`;
	const filter = view.filter ? `filter "${clean(view.filter)}" · ` : "";
	return `${filter}${view.message ? clean(view.message) : `${COLOUR.grey}${help}${COLOUR.fg}`}`;
}

// Read the keyboard in raw mode: Ctrl-C and Ctrl-\ quit, as the signals would.
function onKeys(view, cols, shownRows, keyOf, actions, redraw) {
	if (!process.stdin.isTTY) return;
	process.stdin.setRawMode(true);
	process.stdin.setEncoding("utf8");
	// One read may hold several keys (fast typing, a paste): an arrow's escape sequence, or one character each.
	process.stdin.on("data", (chunk) => {
		for (const [k] of chunk.matchAll(/\x1b\[[0-9;]*[A-Za-z~]|[\s\S]/gu)) key(k);
		redraw();
	});
	const key = (k) => {
		if (k === "\x03") return process.emit("SIGINT");
		if (k === "\x1c") return process.emit("SIGQUIT");
		if (view.editing) {
			if (k === "\r") view.editing = false;
			else if (k === "\x1b") Object.assign(view, { editing: false, filter: "" });
			else if (k === "\x7f" || k === "\b") view.filter = view.filter.slice(0, -1);
			else if (!/[\x00-\x1f]/.test(k)) view.filter += k;
		} else if (view.prompt) {
			const p = view.prompt;
			view.prompt = undefined;
			view.message = k === "y" ? p.run() : `${p.what}: not done`;
		} else {
			const shown = shownRows();
			const i = selectedIndex(view, shown, keyOf);
			view.message = "";
			if (k === "\x1b[A" && i > 0) view.selectedKey = keyOf(shown[i - 1]);
			else if (k === "\x1b[B" && i !== undefined && i < shown.length - 1) view.selectedKey = keyOf(shown[i + 1]);
			else if (k === "<") view.sort = (view.sort + cols.length - 1) % cols.length;
			else if (k === ">") view.sort = (view.sort + 1) % cols.length;
			else if (k === "s") view.desc = !view.desc;
			else if (k === "/") view.editing = true;
			else if (actions[k] && i !== undefined) actions[k](shown[i]);
		}
	};
}

// Run team.sh (the one the tmux option @team-sh names, so its tools/ is the
// team's) and say how it went, in one line.
function runTeam(args) {
	const teamSh = tmux(["show", "-gv", "@team-sh"])?.trim();
	if (!teamSh) return `${args[0]}: not run: the tmux option @team-sh is not set`;
	const r = spawnSync("sh", [teamSh, ...args], { encoding: "utf8", timeout: 60000 });
	const out = `${r.stdout ?? ""}\n${r.stderr ?? ""}`.split("\n").map((l) => l.trim()).filter(Boolean).at(-1) ?? "";
	return `${args[0]} ${args[1]}: ${r.status === 0 ? "done" : `failed (${r.error?.message ?? `exit ${r.status}`})`}${out ? `: ${out}` : ""}`;
}

// The seats table's actions (TB-Q14, TB-Q16): r refreshes, R retires the
// selected seat after a typed y; the key is the operator's go, given in the
// board's pane; retire never passes --no-checkout, and not for the lead.
function seatActions(view) {
	return {
		r: (row) => {
			view.prompt = {
				what: `refresh ${row.seat}`,
				text: `refresh ${row.seat}? type y to confirm, any other key to cancel`,
				run: () => runTeam(["refresh", row.seat, `board: r ${row.seat}`, `board pane ${hhmm(new Date())}`]),
			};
		},
		R: (row) => {
			if (row.seat === "lead") {
				view.message = "retire: not for the lead";
				return;
			}
			view.prompt = {
				what: `retire ${row.seat}`,
				text: `retire ${row.seat}? type y to confirm, any other key to cancel`,
				run: () => runTeam(["retire", row.seat]),
			};
		},
	};
}

// --- the loops -------------------------------------------------------------

function runSeats() {
	const view = makeView(0, false);
	const keyOf = (r) => r.seat;
	let rows = [];
	let head = "";
	let last = "";
	const shown = () => arrange(rows, SEAT_COLS, view);
	const paint = () => {
		const s = shown();
		const selected = selectedIndex(view, s, keyOf);
		draw([head, statusLine(view, `${HELP}  r refresh  R retire`), ...table(SEAT_COLS, s, (process.stdout.columns || 80) - 1, { ...view, selected })]);
	};
	const tick = (force) => {
		const now = new Date();
		const raw = readSeatsRaw();
		const sig = `${raw.sig}|${hhmm(now)}|${process.stdout.columns}x${process.stdout.rows}`;
		if (!force && sig === last) return;
		last = sig;
		rows = buildSeats(raw, now.getTime());
		head = `${COLOUR.bold}Seats${COLOUR.reset} ${rows.length} · ${hhmm(now)}${raw.windows === undefined ? ` · ${COLOUR.high}tmux unreadable${COLOUR.fg}` : ""}`;
		paint();
	};
	onKeys(view, SEAT_COLS, shown, keyOf, seatActions(view), paint);
	process.stdout.on("resize", () => tick(true));
	tick(true);
	setInterval(tick, 2000);
}

function runTasks() {
	const missing = ["VIKUNJA_URL", "VIKUNJA_PROJECT"].filter((v) => !process.env[v]);
	// Worst status first, ties by # (TB-Q10).
	const view = makeView(TASK_COLS.findIndex((c) => c.key === "status"), true);
	const keyOf = (r) => r.id;
	let fetched;
	let error = "";
	let last = "";
	let rows = [];
	let head = "";
	const shown = () => arrange(rows, TASK_COLS, view);
	const paint = () => {
		if (missing.length) return draw([head]);
		const s = shown();
		const selected = selectedIndex(view, s, keyOf);
		const failed = error ? [`${COLOUR.high}${clean(error)}${COLOUR.fg}`] : [];
		draw([head, ...failed, statusLine(view, HELP), ...table(TASK_COLS, s, (process.stdout.columns || 80) - 1, { ...view, selected })]);
	};
	const tick = (force) => {
		const now = new Date();
		const raw = readSeatsRaw();
		const sig = `${raw.sig}|${hhmm(now)}|${fetched?.at}|${error}|${process.stdout.columns}x${process.stdout.rows}`;
		if (!force && sig === last) return;
		last = sig;
		head = `${COLOUR.bold}Tasks${COLOUR.reset}`;
		if (missing.length) {
			head += ` · ${missing.join(", ")} not set`;
		} else {
			rows = fetched ? buildTasks(fetched.tasks, fetched.outside, buildSeats(raw, now.getTime()), process.env.VIKUNJA_URL) : [];
			head += fetched ? ` ${rows.length} · read ${hhmm(new Date(fetched.at))}` : " · reading…";
		}
		paint();
	};
	onKeys(view, TASK_COLS, shown, keyOf, {}, paint);
	const read = async () => {
		try {
			fetched = { ...(await fetchTasks()), at: Date.now() };
			error = "";
		} catch (e) {
			error = `tasks: read failed ${hhmm(new Date())} ${e.message}`;
		}
		tick(true);
	};
	process.stdout.on("resize", () => tick(true));
	tick(true);
	if (!missing.length) {
		read();
		setInterval(read, 60000);
	}
	setInterval(tick, 2000);
}

const CONF_KEYS = ["VIKUNJA_URL", "VIKUNJA_PROJECT", "VIKUNJA_TOKEN_FILE", "TEAM_AGENTS", "TEAM_LEDGER"];

// Fill the variables the environment lacks from board.conf beside the registry.
function loadConf() {
	const { agents } = teamPaths();
	if (!agents) return;
	for (const line of readOr(join(dirname(agents), "board.conf"), "").split("\n")) {
		const m = line.match(/^\s*([A-Z_]+)=(.*)$/);
		if (m && CONF_KEYS.includes(m[1]) && process.env[m[1]] === undefined) process.env[m[1]] = m[2].trim();
	}
}

const self = fileURLToPath(import.meta.url);
if (process.argv[1] === self) {
	const mode = process.argv[2] ?? "both";
	loadConf();
	if (mode === "open") {
		// The team's session: the one holding the lead's pane (TB-Q30).
		const roles = tmux(["list-panes", "-a", "-F", `#{@role}${SEP}#{session_id}`]);
		const session = (roles ?? "").split("\n").map((l) => l.split(SEP)).find((p) => p[0] === "lead")?.[1];
		if (!session) {
			console.error(roles === undefined ? "board.mjs open: cannot read tmux's panes" : "board.mjs open: no pane has @role=lead, so the team's session is unknown");
			process.exit(1);
		}
		const names = tmux(["list-windows", "-t", session, "-F", "#{window_name}"]);
		if (names === undefined) {
			console.error("board.mjs open: cannot list the team session's windows");
			process.exit(1);
		}
		if (names.split("\n").includes("board")) {
			console.log("board: already open");
			process.exit(0);
		}
		const env = CONF_KEYS.concat("TEAM_TMUX").filter((v) => process.env[v] !== undefined).flatMap((v) => ["-e", `${v}=${process.env[v]}`]);
		if (tmux(["new-window", "-b", "-d", "-t", `${session}:0`, "-n", "board", ...env, process.execPath, self]) === undefined) {
			console.error("board.mjs open: tmux new-window failed");
			process.exit(1);
		}
		console.log("board: opened in window 0");
	} else if (mode === "seats") {
		screen();
		runSeats();
	} else if (mode === "tasks") {
		screen();
		runTasks();
	} else if (mode === "both") {
		const pane = process.env.TMUX_PANE;
		if (!pane) {
			console.error("board.mjs: not in tmux; run 'board.mjs seats' or 'board.mjs tasks'");
			process.exit(2);
		}
		const env = CONF_KEYS.concat("TEAM_TMUX")
			.filter((v) => process.env[v] !== undefined).flatMap((v) => ["-e", `${v}=${process.env[v]}`]);
		const right = tmux(["split-window", "-h", "-d", "-P", "-F", "#{pane_id}", "-t", pane, ...env, process.execPath, self, "tasks"])?.trim();
		screen(() => right && tmux(["kill-pane", "-t", right]));
		runSeats();
	} else {
		console.error("usage: board.mjs [seats|tasks|open]");
		process.exit(2);
	}
}
