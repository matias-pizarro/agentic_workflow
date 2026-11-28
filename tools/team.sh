#!/usr/bin/env sh
# Team script of the chief of staff (the lead). One tmux window per agent; the
# window name is the agent's identity. Mechanics follow
# src/chief-of-staff-communication.md (11 Nov 2026).
#   team.sh spawn <name> <cwd> <task file>   start an interactive pi agent with its own session id;
#                                            the task file's first line is the ceremony the user chose:
#                                            Ceremony: <research|write-up|retro|docs|vg|checklist|script|full|none> (the user, "<words>", <date> hh:mm)
#                                            (none for other no-code tasks)
#   team.sh send <name> "<text>"             queue one message for an agent's pane
#   team.sh go <name> "<words>" "<pane> <time>" "<instr>"
#                                            queue "Lead: the user's go ('<words>', <pane> <time>), relayed <now>: <instr>";
#                                            <pane> <time> is where and when the user gave it, e.g. "prod-net pane 22:57"
#   team.sh report "<text>"                  agent -> lead: queue one message for the lead's pane; registers
#                                            each "❓ <ID>" it carries in tools/qids (TEAM_QIDS overrides) and
#                                            refuses an ID registered to another seat, naming it;
#                                            TEAM_QIDS_SKIP=1 relays the text as is, registering nothing
#   team.sh status                           last STATUS line of every agent, [busy], [input box holds text] and
#                                            [input box unreadable] flags; queued messages (saying which) and failed ones;
#                                            a CRON line when the last run in tools/spool/cron.log exited non-zero;
#                                            a WIKI line when the wiki's last commit outside sources/ is a day old
#                                            or more, or unreadable (rules.md rule 11; TEAM_WIKI overrides the wiki)
#   team.sh waiting                          the rows of the lead's "Waiting for you" table: one per seat whose last
#                                            STATUS line has open above 0 or says waiting-for-PM, from its window's
#                                            options (open-questions.ts sets them), never from memory (RT4-Q5 (b))
#   team.sh refresh <name>…|all|lead [--min <percent>] "<the user's words>" "<pane> <time>"
#                                            with --min, a seat whose context window (@ctx) is below the percent,
#                                            or unknown, is skipped and listed, with its percentage when known (CS-Q90)
#                                            hand each seat (all: every recorded one; lead: the lead) to a
#                                            new session in its pane, through a handoff; returns at once,
#                                            one background run per seat reporting to the lead when it ends
#                                            (.scratch/refresh/perimeter.md; typed as /refresh in the lead's pane)
#   team.sh retire <name> [--no-checkout "<reason>"]
#                                            close a finished agent's window, drop its record; refused while
#                                            wiki/sources/checkouts/<yyyy-mm-dd>-<name>.md (TEAM_CHECKOUTS overrides
#                                            the directory) is missing, unreadable or empty, unless --no-checkout gives a
#                                            reason, which goes to the log (rules.md, Team mechanics; AW-Q86)
#   team.sh revive <name>|--all              after a tmux restart, reopen recorded agents in their sessions;
#                                            --all also reopens the team board in window 0, the phone bot's pane below it (board.mjs open)
#   team.sh queue                            undelivered and failed messages
#   team.sh selftest                         test delivery, go, spawn and revive on tmux -L teamtest
#   team.sh doctor                           check the host dependencies in tools/expect; print one fix block
# Every agent ends each turn with: STATUS seat=<name> state=<state>
# [for=<PM|lead|seat-name>] open=<n> [worst=<high|medium|low>] [ask="<one
# sentence>"] [pointer=<path or commit>] (for: who it waits for; open: its
# questions to the operator still unanswered; worst: the highest criticality
# among them). status prints that line; the tab colour follows it.
# spawn records each agent as "name<TAB>cwd<TAB>task file<TAB>session id" in
# tools/agents (git-ignored; TEAM_AGENTS overrides), and starts it without
# TEAM_ROLE in its environment (the lead runs with TEAM_ROLE=lead, which the
# untracked pre-commit hook of src refuses).
# send and report never type into a pane whose input box holds text (the user
# may be mid-sentence there): the message goes to a spool (tools/spool/<target>/q),
# and a background deliverer, one per target (mkdir lock), types the queued
# messages in order, each only once the input box is empty, retrying every
# TEAM_POLL (3) seconds for up to TEAM_WAIT (14400, 4 h) seconds; then the
# message moves to tools/spool/<target>/failed. Log: tools/spool/log. send, go
# and report say when the target's pane is busy: pi then holds a typed message
# as steering, read after the agent's current step (pi's rpc-commands.md).
# status lists every queued message with its age.
# send, go, report, spawn and revive set the tmux server option @team-qids to
# the question-ID registry's path, where the pi extension open-questions.ts
# registers each pane's new IDs (RT3-Q9), @team-sh to this script's path,
# which the pi extension draft.ts runs to relay a /draft to the lead (AW-Q70),
# and @team-ledger to the ledger's path, tools/ledger (git-ignored; TEAM_LEDGER
# overrides), where the pi extension ledger.ts logs each session's start and
# stop, refresh its events (RF-Q5), and spawn a "spawn" line, the seat's
# creation, which the team board shows (TB-Q5). spawn names each session
# "<name> <YYYY-MM-DD hh:mm>" (RF-Q8).
# refresh writes the handoff and task files to wiki/sources/cos-archive
# (TEAM_HANDOFFS overrides), uncommitted: the lead commits them.
# tools/ is the directory of the path the script was invoked by, not of its
# resolved target: a symlink <root>/wiki/tools/team.sh to
# <root>/agentic_workflow/tools/team.sh
# keeps the spool and tools/agents in the wiki (14 Nov 2026).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
self=$here/$(basename "$0")
spool=${TEAM_SPOOL:-$here/spool}
wait_max=${TEAM_WAIT:-14400}
poll=${TEAM_POLL:-3}
agents=${TEAM_AGENTS:-$here/agents}
qids=${TEAM_QIDS:-$here/qids}
ledger=${TEAM_LEDGER:-$here/ledger}
handoffs=${TEAM_HANDOFFS:-$here/../sources/cos-archive}
checkouts=${TEAM_CHECKOUTS:-$here/../sources/checkouts}
start_wait=${TEAM_START_WAIT:-60}
pi_cmd=${TEAM_PI:-pi}
tab=$(printf '\t')
rule=$(printf '\342\224\200') # the box-drawing character of pi's rules
cr=$(printf '\r')

# TEAM_TMUX names a separate tmux server (tmux -L), used by selftest.
tmux() { command tmux ${TEAM_TMUX:+-L "$TEAM_TMUX"} "$@"; }

die() { echo "$*" >&2; exit 1; }

# Single-quote a string for sh.
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# The lead pane carries the tmux pane option @role=lead (set by the lead with
# tmux set -p @role lead), so a restarted lead keeps receiving reports.
lead_pane() { tmux list-panes -a -F "#{pane_id} #{@role}" | awk '$2 == "lead" { print $1; exit }'; }

# Print the lines of a pi pane's input box: the lines between the last rule made
# only of $rule and the nearest rule above it (that one may carry a label, as in
# "── ⠸ Working ──" while the agent is busy). Fail if there is no such box.
input_box() { # pane
  tmux capture-pane -p -t "$1" 2>/dev/null | box_of
}
box_of() { # a pane's text on stdin
  LC_ALL=C awk -v r="$rule" '
    function isrule(s) { return length(s) > 0 && substr(s, 1, length(r)) == r }
    function pure(s,   x) { x = s; gsub(r, "", x); gsub(/ /, "", x); return isrule(s) && x == "" }
    { l[NR] = $0 }
    END {
      for (b = NR; b > 0 && !pure(l[b]); b--) ;
      for (t = b - 1; t > 0 && !isrule(l[t]); t--) ;
      if (t <= 0) exit 1
      for (i = t + 1; i < b; i++) print l[i]
    }'
}
input_empty() { # pane
  box=$(input_box "$1") || return 1
  [ -z "$(printf '%s' "$box" | tr -d ' \t\n')" ]
}

# A pane is busy while pi's "Working" line shows near its bottom.
busy() { tmux capture-pane -p -J -t "$1" 2> /dev/null | tail -8 | grep -q 'Working'; }

# Seconds since a file was last changed (GNU stat, else BSD stat).
mtime() { stat -c %Y "$1" 2> /dev/null || stat -f %m "$1"; }

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$spool/log"; }

# Print a line for the caller. A caller that stopped reading ("team.sh send …
# | head -1") must not kill team.sh before its next step, as SIGPIPE, or a
# failed write under set -e, would: the write is tried with SIGPIPE ignored,
# in a subshell, and its failure dropped. say_err prints to stderr.
say() { (trap '' PIPE; printf '%s\n' "$*") 2> /dev/null || true; }
say_err() { (trap '' PIPE; printf '%s\n' "$*" >&2) || true; }

# mkdir lock holding the owner's pid; a lock whose owner is gone is removed.
lock() { # dir
  mkdir "$1" 2>/dev/null && { echo $$ > "$1/pid"; return 0; }
  owner=$(cat "$1/pid" 2>/dev/null) || return 1
  kill -0 "$owner" 2>/dev/null && return 1
  rm -rf "$1"
  mkdir "$1" 2>/dev/null && { echo $$ > "$1/pid"; return 0; }
  return 1
}

resolve() { # target -> pane id (empty if absent)
  case $1 in
  lead) lead_pane ;;
  to-*) tmux display -p -t "${1#to-}" '#{pane_id}' 2>/dev/null || true ;;
  esac
}

# Tell pi panes where the question-ID registry is; no tmux server, no matter.
publish_qids() {
  tmux set -g @team-qids "$qids" 2> /dev/null && tmux set -g @team-sh "$self" 2> /dev/null &&
    tmux set -g @team-ledger "$ledger" 2> /dev/null || true
}

# The last cron run, when it exited non-zero: "CRON <name> exit <n>, <d Mon hh:mm>: see <log>".
# cron.log lines: "<YYYY-MM-DD> <hh:mm:ss> <TZ> run: <command>", then its output, then "... exit <n>".
cron_flag() {
  [ -f "$spool/cron.log" ] || return 0
  awk -v path="$spool/cron.log" '
    $4 == "run:" { name = $5; for (i = 5; i < NF; i++) if ($i == "spawn") { name = $(i + 1); break } }
    $4 == "exit" { rc = $5; when = $1 " " substr($2, 1, 5) }
    END {
      if (rc == "" || rc == 0) exit
      split(when, w, /[- ]/)
      m = substr("JanFebMarAprMayJunJulAugSepOctNovDec", (w[2] - 1) * 3 + 1, 3)
      printf "CRON %s exit %s, %d %s %s: see %s\n", name, rc, w[3], m, w[4], path
    }' "$spool/cron.log"
}

# The wiki's last commit outside sources/, when a day old or more, or unreadable (AW-Q182):
# "WIKI last entry outside sources/ <n>h ago (<hash>): ...". The wiki is TEAM_WIKI, else the
# directory above tools/ when it holds index.md (team.sh called as <root>/wiki/tools/team.sh),
# else <root>/wiki beside agentic_workflow (called as <root>/agentic_workflow/tools/team.sh,
# AW-Q183). It must be its own git repository, not a folder of another (AW-Q184).
wiki_flag() {
  w=${TEAM_WIKI:-$here/..}
  [ -n "${TEAM_WIKI:-}" ] || [ -f "$w/index.md" ] || w=$here/../../wiki
  [ -f "$w/index.md" ] || return 0
  top=$(git -C "$w" rev-parse --show-toplevel 2> /dev/null) || top=''
  if [ -z "$top" ] || [ "$(cd "$top" && pwd -P)" != "$(cd "$w" && pwd -P)" ]; then
    echo "WIKI last entry outside sources/: unreadable ($w is not a git repository of its own)"
    return 0
  fi
  if ! last=$(git -C "$w" log -1 --format='%ct %h' -- . ':(exclude)sources' 2> /dev/null) || [ -z "$last" ]; then
    echo "WIKI last entry outside sources/: unreadable (git log failed in $w)"
    return 0
  fi
  age=$((($(date +%s) - ${last% *}) / 3600))
  [ "$age" -lt 24 ] ||
    echo "WIKI last entry outside sources/ ${age}h ago (${last#* }): write the decisions since then as dated entries (rules.md rule 11)"
}

# Append text to the target's queue, then make sure a deliverer runs.
enqueue() { # target text
  publish_qids
  d=$spool/$1
  mkdir -p "$d/q" "$d/failed"
  tmp=$d/new.$$
  printf '%s' "$2" > "$tmp"
  i=0
  until lock "$d/seq.lock"; do
    i=$((i + 1)); [ $i -lt 100 ] || { echo "cannot lock $d/seq.lock" >&2; rm -f "$tmp"; exit 1; }
    sleep 0.1
  done
  n=$(($(cat "$d/seq" 2>/dev/null || echo 0) + 1))
  echo "$n" > "$d/seq"
  f=$(printf '%s/q/%09d' "$d" "$n")
  mv "$tmp" "$f"
  rm -rf "$d/seq.lock"
  log "queued $f"
  # Start the deliverer from the tmux server, outside the caller's process
  # tree: pi kills the process group of its bash calls, and timeout(1), a
  # process reaper on FreeBSD, kills every descendant of its command, detached
  # or not, when it fires (TD-Q1, 17 Nov). The server does not inherit this
  # shell's environment, so the settings go on the command line. Without a
  # reachable server no pane can be typed into anyway: the message stays
  # queued, and status shows it with no deliverer.
  dcmd="TEAM_SPOOL=$(q "$spool") TEAM_POLL=$(q "$poll") TEAM_WAIT=$(q "$wait_max") TEAM_TMUX=$(q "${TEAM_TMUX:-}") sh $(q "$self") _deliver $(q "$1") >> $(q "$spool/log") 2>&1"
  if ! tmux run-shell -b "$dcmd" 2> /dev/null; then
    say_err "no deliverer started for $1: the tmux server cannot be reached; it stays queued"
    log "no deliverer started for $1: tmux server unreachable"
  fi
  say "queued for $1: $f"
  p=$(resolve "$1" 2> /dev/null) || p=''
  if [ -n "$p" ] && busy "$p"; then
    say "${1#to-} is busy: once typed, pi holds the message as steering until the agent's current step ends; while its input box holds text it waits here (team.sh status: QUEUED)"
  fi
}

# Type one queued message once the target's input box is empty. Text and Enter
# (a carriage return) go in one send-keys call, right after the check, so no
# keystroke of the user can land between them.
deliver_one() { # target file
  deadline=$(($(date +%s) + wait_max))
  text=$(cat "$2")
  while [ "$(date +%s)" -lt "$deadline" ]; do
    pane=$(resolve "$1")
    if [ -n "$pane" ] && input_empty "$pane"; then
      tmux send-keys -t "$pane" -l -- "$text$cr"
      log "delivered $2 to $pane"
      rm -f "$2"
      sleep 1 # let the TUI take the submission before the next check
      return 0
    fi
    sleep "$poll"
  done
  return 1
}

deliver() { # target
  d=$spool/$1
  while lock "$d/deliver.lock"; do
    trap 'rm -rf "$d/deliver.lock"' EXIT
    trap 'exit 1' INT TERM HUP
    while :; do
      first=''
      for f in "$d"/q/*; do [ -f "$f" ] && first=$f; break; done
      [ -n "$first" ] || break
      deliver_one "$1" "$first" || { mv "$first" "$d/failed/"; log "FAILED $first: input box of $1 not empty or not found for ${wait_max}s"; }
    done
    rm -rf "$d/deliver.lock"
    trap - EXIT INT TERM HUP
    # A message queued while the lock was being released would be stranded.
    for f in "$d"/q/*; do [ -f "$f" ] && continue 2; done
    break
  done
}

# The seat a report comes from: its tmux window's name, else the text's
# "<name>:" prefix.
reporter() { # text
  if [ -n "${TMUX_PANE:-}" ] && w=$(tmux display -p -t "$TMUX_PANE" '#{window_name}' 2> /dev/null) && [ -n "$w" ]; then
    echo "$w"
  else
    printf '%s\n' "$1" | sed -n '1s/^\([A-Za-z0-9._-][A-Za-z0-9._-]*\):.*/\1/p'
  fi
}

# Register each question ID a report carries ("❓ <ID>", <ID> as AW-Q3 or
# NET-Q6b) as "ID<TAB>seat<TAB>date" in $qids, so no two seats ask under one
# ID (rules.md rule 4). Refuse the whole report when an ID is another seat's.
register_qids() { # text
  ids=$(printf '%s\n' "$1" | grep -oE '❓ *\**[A-Z][A-Za-z0-9-]*-Q[0-9]+[a-z]?' | sed 's/^❓ *\**//' | sort -u) || true
  [ -n "$ids" ] || return 0
  seat=$(reporter "$1")
  [ -n "$seat" ] || die "report: it carries ❓ IDs but names no seat; start it with \"<name>: \""
  i=0
  until lock "$qids.lock"; do
    i=$((i + 1)); [ $i -lt 100 ] || die "report: cannot lock $qids.lock"
    sleep 0.1
  done
  taken='' new=''
  for id in $ids; do
    if [ -e "$qids" ]; then
      owner=$(awk -F '\t' -v i="$id" '$1 == i { print $2 "'\''s (" $3 ")"; exit }' "$qids") ||
        { rm -rf "$qids.lock"; die "report: cannot read $qids; not sent"; }
    else
      owner=''
    fi
    case $owner in
    '') new="$new $id" ;;
    "$seat's ("*) ;;
    *) taken="$taken ❓ $id is $owner;" ;;
    esac
  done
  if [ -n "$taken" ]; then
    rm -rf "$qids.lock"
    die "report: not sent:$taken number yours <PREFIX>-$seat-Qn or take the next free number"
  fi
  d=$(date '+%e %b %Y' | sed 's/^ //')
  for id in $new; do printf '%s\t%s\t%s\n' "$id" "$seat" "$d" >> "$qids"; done
  rm -rf "$qids.lock"
}

# The first message of an agent: the protocol, then its task file. Prints the
# path of a temporary file holding it.
compose_prompt() { # name task-file
  full=$(mktemp "${TMPDIR:-/tmp}/cos-task-$1.XXXXXX")
  cat > "$full" <<HDR
You are the agent \`$1\` on a team led by a chief of staff (the lead). Protocol:
- End EVERY turn with exactly one line:
  STATUS seat=$1 state=<working|waiting-for-PM|waiting-for-seat|ready-for-lead|blocked|idle|done> [for=<PM|lead|seat-name>] open=<n> [worst=<high|medium|low>] [ask="<one sentence>"] [pointer=<path or commit>]
  (for: who you wait for, PM with waiting-for-PM, lead with ready-for-lead, the first seat waited for with waiting-for-seat, left out otherwise;
  open: your questions to the operator still unanswered; worst: the highest criticality among them, whenever open > 0)
- When you finish, or need the lead, also run:
  $here/team.sh report "$1: <one or two sentences, with a pointer (path or commit)>"
  then end your turn. Never paste file contents into a report; name the path.
- The principal (the user) may type into your pane; a go given there is valid. Quote it (words and time) in your report.
- Messages from the lead arrive in your pane as new user messages.

Your task:
HDR
  cat "$2" >> "$full"
  echo "$full"
}

# The registry's lock, taken by every change to it: spawn, retire and refresh
# (RF-Q18). Fails after 10 s.
registry_lock() {
  i=0
  until lock "$agents.lock"; do
    i=$((i + 1)); [ $i -lt 100 ] || return 1
    sleep 0.1
  done
}

# The agent's line in the registry: name, cwd, task file, session id (tabs).
record() { # name
  [ -f "$agents" ] && awk -F '\t' -v n="$1" '$1 == n { print; f = 1; exit } END { exit !f }' "$agents"
}

window_exists() { # name
  tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qxF -- "$1"
}

# A pi session file with this id, under pi's session directory.
session_exists() { # id
  root=${PI_CODING_AGENT_SESSION_DIR:-$HOME/.pi/agent/sessions}
  for f in "$root"/*/*_"$1".jsonl "$root"/*_"$1".jsonl; do
    [ -f "$f" ] && return 0
  done
  return 1
}

# Open the agent's window running pi in its session; with a prompt file, pi
# gets its content as the first message. TEAM_ROLE is cleared for the agent.
open_window() { # name cwd session-id [session name, prompt file]
  tmux new-window -d -n "$1" -c "$2" "bash -ic $(q "unset TEAM_ROLE; exec $(shift 2; pi_line "$@")")"
}

# The pi command line: a session id, then a session name and a first message
# read from a file, when given.
pi_line() { # session-id [session name, prompt file]
  printf '%s --session-id %s' "$(q "$pi_cmd")" "$(q "$1")"
  [ $# -lt 3 ] || printf ' --name %s "$(cat %s)"' "$(q "$2")" "$(q "$3")"
}

# The session name a seat's new session gets (RF-Q8).
session_name() { echo "$1 $(date '+%F %H:%M')"; }

# A task file must exist and hold more than blank space.
task_ok() { [ -f "$1" ] && grep -q '[^[:space:]]' "$1"; }

# The task file's first line names the ceremony the user chose, with their
# words and time (wiki decision-ceremony-sizing.md).
ceremony_ok() {
  first=$(head -n 1 "$1") || return 1
  grep -Eq '^Ceremony: (research|write-up|retro|docs|vg|checklist|script|full|none) .*"[^"]+".*[0-9][0-9]:[0-9][0-9]' <<EOF
$first
EOF
}

revive_one() { # name
  rec=$(record "$1") || { say_err "$1 is not recorded in $agents"; return 1; }
  cwd=$(printf '%s\n' "$rec" | cut -f2)
  task=$(printf '%s\n' "$rec" | cut -f3)
  id=$(printf '%s\n' "$rec" | cut -f4)
  if window_exists "$1"; then
    say "$1: window exists, left alone"
  elif session_exists "$id"; then
    open_window "$1" "$cwd" "$id"
    say "revived $1 in session $id"
  elif task_ok "$task"; then
    # pi saves a session only once it has a reply; start over from the task.
    open_window "$1" "$cwd" "$id" "$(session_name "$1")" "$(compose_prompt "$1" "$task")"
    say "revived $1: no saved session $id, restarted from $task"
  else
    say_err "$1: no saved session $id and task file $task is missing or empty; not revived"
    return 1
  fi
}

# After a tmux restart no pane has @role=lead; revive is run by the lead, so
# its own pane gets it, unless that pane is an agent's.
ensure_lead() {
  [ -z "$(lead_pane 2>/dev/null)" ] || return 0
  if [ -z "${TMUX_PANE:-}" ]; then
    say_err "no pane has @role=lead; run tmux set -p @role lead in the lead pane"
    return 0
  fi
  win=$(tmux display -p -t "$TMUX_PANE" '#{window_name}')
  if record "$win" > /dev/null; then
    say_err "no pane has @role=lead, and $TMUX_PANE is agent $win's; run tmux set -p @role lead in the lead pane"
    return 0
  fi
  tmux set -p -t "$TMUX_PANE" @role lead
  say "set @role=lead on $TMUX_PANE"
}

# refresh: decisions RF-Q1 to RF-Q12 in .scratch/refresh/perimeter.md, failure
# modes in .scratch/refresh/issues/01-refresh.md.

# Append one line to the ledger; a failed append is kept in $ledger_err for
# the run's report, and the refresh carries on (RF-Q10).
ledger_err=''
ledger_add() { # event seat session-id session-name detail
  d=$(printf '%s' "$5" | tr '\t\n' '  ')
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T %Z')" "$1" "$2" "$3" "$4" "$d" >> "$ledger" 2> /dev/null ||
    ledger_err="ledger write failed: cannot append to $ledger"
}

# The pane of a seat (lead: the pane with @role=lead); empty if none; fails
# (status 2) if tmux's panes cannot be read (RF-Q19).
seat_pane() { # seat
  if [ "$1" = lead ]; then
    ps=$(tmux list-panes -a -F '#{@role} #{pane_id}' 2> /dev/null) || return 2
    printf '%s\n' "$ps" | awk '$1 == "lead" { print $2; exit }'
  else
    ps=$(tmux list-panes -a -F '#{window_name} #{pane_id}' 2> /dev/null) || return 2
    printf '%s\n' "$ps" | awk -v n="$1" '$1 == n { print $2; exit }'
  fi
}

# The spool target of a seat's messages.
target_of() { if [ "$1" = lead ]; then echo lead; else echo "to-$1"; fi; }

# A pi pane's state: busy (pi's "Working" line), typing (its input box holds
# text), idle, or unreadable (no capture, or no input box). A failed read is
# unreadable, never idle.
pane_state() { # pane
  [ -n "$1" ] || { echo unreadable; return; }
  s=$(tmux capture-pane -p -J -t "$1" 2> /dev/null) || { echo unreadable; return; }
  if printf '%s\n' "$s" | tail -8 | grep -q 'Working'; then echo busy; return; fi
  s=$(tmux capture-pane -p -t "$1" 2> /dev/null) || { echo unreadable; return; }
  box=$(printf '%s\n' "$s" | box_of) || { echo unreadable; return; }
  if [ -n "$(printf '%s' "$box" | tr -d ' \t\n')" ]; then echo typing; else echo idle; fi
}

# Whether a message waits in a target's queue: yes, no, or failed. A queue
# is absent only when the nearest directory above it can be searched (RF-Q19).
queued_for() { # target
  d=$spool/$1/q
  if [ -e "$d" ]; then
    [ -r "$d" ] && [ -x "$d" ] || { echo failed; return; }
    for f in "$d"/*; do [ -e "$f" ] && { echo yes; return; }; done
    echo no
    return
  fi
  for a in "$spool/$1" "$spool" "$(dirname "$spool")"; do
    if [ -e "$a" ]; then
      if [ -x "$a" ]; then echo no; else echo failed; fi
      return
    fi
  done
  echo failed
}

# Take a seat's refresh lock, or print since when a refresh of it runs. The
# background run writes its pid into the lock; a lock whose run is gone is
# taken over.
refresh_lock() { # seat
  d=$spool/refresh/$1.lock
  mkdir -p "$spool/refresh" || return 1
  if ! mkdir "$d" 2> /dev/null; then
    p=$(cat "$d/pid" 2> /dev/null) || p=''
    if [ -n "$p" ] && ! kill -0 "$p" 2> /dev/null; then
      rm -rf "$d"
      mkdir "$d" 2> /dev/null || { echo "refresh of $1: cannot take its lock $d"; return 1; }
    else
      echo "refresh of $1 already running since $(cat "$d/since" 2> /dev/null || echo '(unknown)')"
      return 1
    fi
  fi
  date '+%H:%M' > "$d/since"
}

# The session a seat's pane holds: "<id><TAB><name>", from the pane options
# ledger.ts sets, else the registry's id.
# A failed read is written "(unreadable)", never replaced by another value
# (RF-Q19); the registry's id stands in only for an unset option.
session_of() { # seat pane
  if [ -z "$2" ]; then printf '(unreadable)\t(unreadable)\n'; return; fi
  i=$(tmux display -p -t "$2" '#{@session-id}' 2> /dev/null) || i='(unreadable)'
  n=$(tmux display -p -t "$2" '#{@session-name}' 2> /dev/null) || n='(unreadable)'
  if [ -z "$i" ] && [ "$1" != lead ]; then
    if r=$(record "$1"); then i=$(printf '%s\n' "$r" | cut -f4); else i='(unreadable)'; fi
  fi
  printf '%s\t%s\n' "$i" "$n"
}

# The environment of a background run, on its command line: the tmux server
# does not pass on this shell's.
run_env() {
  for v in TEAM_SPOOL:"$spool" TEAM_POLL:"$poll" TEAM_WAIT:"$wait_max" TEAM_TMUX:"${TEAM_TMUX:-}" \
    TEAM_AGENTS:"$agents" TEAM_QIDS:"$qids" TEAM_LEDGER:"$ledger" TEAM_HANDOFFS:"$handoffs" \
    TEAM_START_WAIT:"$start_wait" TEAM_PI:"$pi_cmd" PI_CODING_AGENT_SESSION_DIR:"${PI_CODING_AGENT_SESSION_DIR:-}"; do
    printf '%s=%s ' "${v%%:*}" "$(q "${v#*:}")"
  done
}

# End a refresh run: log the event (none if empty), report to the lead once.
refresh_end() { # event detail report
  ended=1
  [ -z "$1" ] || ledger_add "$1" "$seat" "$old_id" "$old_name" "$2"
  refresh_report "$3"
  exit 0
}

# Queue the run's one report; one that cannot be queued goes to the spool's
# log (RF-Q20).
refresh_report() { # text
  t="refresh $seat: $1${ledger_err:+; $ledger_err}"
  (enqueue lead "$t") > /dev/null 2>&1 || log "report for the lead NOT QUEUED: $t"
}

# The run's EXIT trap: an end that did not go through refresh_end (a failed
# command under set -e) is logged and reported too (RF-Q20).
refresh_exit() { # exit status
  if [ -z "$ended" ]; then
    ended=1
    ledger_add refresh-failed "$seat" "${old_id:-}" "${old_name:-}" "step $step: stopped unexpectedly (exit $1)"
    refresh_report "failed: step $step: the run stopped unexpectedly (exit $1); see $spool/log"
  fi
  # Only this run's own lock (review round 2, finding 5).
  [ "$(cat "$lk/pid" 2> /dev/null)" != "$$" ] || rm -rf "$lk"
}

# The background run of one seat's refresh: defer, ask for the handoff, check
# it, write the task file, rewrite the registry, restart pi in the pane.
refresh_run() { # seat words source
  seat=$1 words=$2 src=$3
  lk=$spool/refresh/$seat.lock
  step=0 ended='' old_id='' old_name=''
  trap 'refresh_exit $?' EXIT
  trap 'exit 1' INT TERM HUP
  (set -C; echo $$ > "$lk/pid") # claim the lock the foreground took; fails if a run holds it
  real=$(cd "$(dirname "$(readlink -f "$self")")" && pwd)
  rules=$(cd "$real/../docs" && pwd)/rules.md
  qt=$(target_of "$seat")
  pane=$(seat_pane "$seat") || pane=''
  s=$(session_of "$seat" "$pane")
  old_id=$(printf '%s' "$s" | cut -f1) old_name=$(printf '%s' "$s" | cut -f2)
  old_shown=${old_name:-unnamed} # a session spawned before v2.3.0 has no name (AW-Q88)

  # 1. Deferred while busy, typing or a message is queued (RF-Q6).
  step=1
  deadline=$(($(date +%s) + wait_max)) last=''
  while :; do
    pane=$(seat_pane "$seat") || pane='' # a failed read: unreadable, below
    why=''
    case $(pane_state "$pane") in
    unreadable) refresh_end refresh-unadvisable "pane unreadable" "unadvisable: pane unreadable (no pi input box in $seat's pane)" ;;
    busy) why=busy ;;
    typing) why='input box holds text' ;;
    esac
    if [ -z "$why" ]; then
      case $(queued_for "$qt") in yes) why='message queued' ;; failed) why='its message queue is unreadable' ;; esac
    fi
    [ -n "$why" ] || break
    [ "$why" = "$last" ] || { ledger_add refresh-deferred "$seat" "$old_id" "$old_name" "$why"; last=$why; }
    [ "$(date +%s)" -lt "$deadline" ] || refresh_end refresh-failed "still deferred: $why" "failed: still deferred: $why after ${wait_max}s"
    sleep "$poll"
  done

  # 2. Ask for the handoff; wait for the file and the pane idle again (RF-Q7).
  step=2
  stamp=$(date '+%Y-%m-%d-%H%M')
  mkdir -p "$handoffs" 2> /dev/null || refresh_end refresh-failed "handoff directory: cannot create $handoffs" "failed: cannot create $handoffs"
  # A refresh of the seat earlier in the same minute left its file: take the next free name.
  h=$handoffs/handoff-$stamp-$seat.md k=1
  while [ -e "$h" ]; do k=$((k + 1)); h=$handoffs/handoff-$stamp-$seat-$k.md; done
  enqueue "$qt" "Lead: a refresh of your seat is requested (the user, \"$words\", $src): write your handoff to $h following $real/handoff.md, its first line exactly '# Handoff: seat $seat, <d Mon YYYY> <hh:mm>'. If a refresh now would lose work (an async subagent or background job that reports to this session, a live run under way, a merge stopped mid-conflict, an answer of the user's you are about to act on), write there only the line 'REFRESH-UNADVISABLE: <reason>' instead. Then end your turn: this session then stops, and a new one takes the seat from your handoff." > /dev/null
  deadline=$(($(date +%s) + wait_max))
  while :; do
    [ -e "$h" ] || { [ -d "$handoffs" ] && [ -x "$handoffs" ]; } ||
      refresh_end refresh-failed "cannot read $handoffs" "failed: cannot read the handoff directory $handoffs"
    if [ -f "$h" ] && [ "$(queued_for "$qt")" = no ]; then
      [ "$(pane_state "$(seat_pane "$seat")")" != idle ] || break # never while its box holds text (RF-Q17)
    fi
    [ "$(date +%s)" -lt "$deadline" ] || refresh_end refresh-failed "no handoff at $h" "failed: no handoff at $h, or the pane not idle, after ${wait_max}s"
    sleep "$poll"
  done

  # 3. Check it.
  step=3
  first=$(head -n 1 "$h" 2> /dev/null) || refresh_end refresh-failed "handoff unreadable: $h" "failed: handoff unreadable: $h"
  case $first in
  REFRESH-UNADVISABLE:*)
    r=${first#REFRESH-UNADVISABLE:}
    refresh_end refresh-unadvisable "${r# }" "unadvisable: ${r# } (the seat's answer, $h)" ;;
  "# Handoff: seat $seat, "*) ;;
  *) refresh_end refresh-failed "bad handoff $h: $first" "failed: bad handoff $h: its first line is '$first'" ;;
  esac
  ledger_add handoff-written "$seat" "$old_id" "$old_name" "$h"

  # 4. The task file (RF-Q9).
  step=4
  new_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  [ -n "$new_id" ] || refresh_end refresh-failed "uuidgen gave no session id" "failed: uuidgen gave no session id"
  name=$(session_name "$seat")
  task=$handoffs/task-$seat-refresh-$stamp.md
  [ "$k" = 1 ] || task=$handoffs/task-$seat-refresh-$stamp-$k.md
  day=$(date '+%e %b %Y' | sed 's/^ //')
  {
    printf 'Ceremony: none (the user, "%s", %s %s)\n\n' "$words" "$day" "${src##* }"
    if [ "$seat" = lead ]; then
      printf 'You are the lead, the chief of staff of this team, taking over from session `%s` (%s), refreshed at the user'\''s request. Load the chief-of-staff skill. Read first, whole, in order:\n1. %s (the outgoing session'\''s handoff).\n2. %s.\n3. %s.\n\nThen run `%s status`.\n' \
        "$old_shown" "$old_id" "$h" "$(cd "$here/.." && pwd)/index.md" "$rules" "$here/team.sh"
    else
      printf 'You take over the seat `%s` from session `%s` (%s), refreshed at the user'\''s request. Read first, whole, in order:\n1. %s (the outgoing session'\''s handoff).\n2. %s.\n\nAsk again in your pane, in full, every open question the handoff lists, under the same IDs. Then report to the lead with `team.sh report` that you hold the seat, naming the handoff, and end your turn with your STATUS line.\n' \
        "$seat" "$old_shown" "$old_id" "$h" "$rules"
    fi
  } > "$task" 2> /dev/null || refresh_end refresh-failed "task file: cannot write $task" "failed: cannot write the task file $task"

  # 5. The registry, under a lock: runs of /refresh all rewrite it at once.
  step=5
  if [ "$seat" != lead ]; then
    registry_lock || refresh_end refresh-failed "registry: cannot lock $agents.lock" "failed: registry: cannot lock $agents.lock"
    if ! err=$(awk -F '\t' -v OFS='\t' -v n="$seat" -v t="$task" -v i="$new_id" '$1 == n { $3 = t; $4 = i } { print }' "$agents" 2>&1 > "$agents.new.$$") ||
      ! err=$(mv "$agents.new.$$" "$agents" 2>&1); then
      rm -rf "$agents.lock" "$agents.new.$$"
      err=$(printf '%s' "$err" | tr '\n' ' ')
      refresh_end refresh-failed "registry: cannot rewrite $agents: $err" "failed: registry: cannot rewrite $agents: $err"
    fi
    rm -rf "$agents.lock"
  fi

  # 6. Stop the old pi, start the new one in the same pane (RF-Q2, RF-Q12).
  step=6
  pane=$(seat_pane "$seat") && [ -n "$pane" ] ||
    refresh_end refresh-failed "respawn: the pane cannot be found" "failed: respawn: $seat's pane cannot be found or read; the registry names the new session $new_id: team.sh revive $seat"
  if [ "$seat" = lead ]; then
    cwd=$(tmux display -p -t "$pane" '#{pane_current_path}' 2> /dev/null) && [ -n "$cwd" ] ||
      refresh_end refresh-failed "respawn: the lead pane's directory cannot be read" "failed: respawn: the lead pane's directory cannot be read; old session $old_id kept"
    cmd="bash -ic $(q "TEAM_ROLE=lead $(pi_line "$new_id" "$name" "$task"); exec bash")"
  else
    r=$(record "$seat") && cwd=$(printf '%s\n' "$r" | cut -f2) && [ -n "$cwd" ] ||
      refresh_end refresh-failed "respawn: $seat's directory cannot be read from $agents" "failed: respawn: $seat's directory cannot be read from $agents; old session $old_id kept; the registry names the new session $new_id: team.sh revive $seat"
    cmd="bash -ic $(q "unset TEAM_ROLE; exec $(pi_line "$new_id" "$name" "$(compose_prompt "$seat" "$task")")")"
  fi
  both="old session $old_id ($old_shown), new $new_id ($name)"
  err=$(tmux respawn-pane -k -t "$pane" -c "$cwd" "$cmd" 2>&1) ||
    refresh_end refresh-failed "respawn: $err" "failed: respawn: $err; $both; the registry names the new one: team.sh revive $seat"

  # 7. Wait for the new pi's input box.
  step=7
  # Done only once pi's input box shows and ledger.ts has set the pane's
  # @session-id to the new id (RF-Q21).
  i=0
  until input_box "$pane" > /dev/null && [ "$(tmux display -p -t "$pane" '#{@session-id}' 2> /dev/null)" = "$new_id" ]; do
    i=$((i + 1))
    if [ $i -ge "$start_wait" ]; then
      if shown=$(tmux capture-pane -p -t "$pane" 2> /dev/null); then
        shown="the pane shows: $(printf '%s\n' "$shown" | grep . | tail -5 | tr '\n' '|')"
      else
        shown='the pane closed'
      fi
      refresh_end refresh-failed "no pi in pane" "failed: no pi in pane after ${start_wait}s; $both, the old one stopped, its session saved; $shown (a pi without ledger.ts loaded never sets @session-id: is it installed?)"
    fi
    sleep 1
  done
  refresh_end '' '' "done: $name ($new_id) holds the seat, from $h and $task (uncommitted); $old_shown ($old_id) stopped"
}

# doctor: check each host dependency in tools/expect (TEAM_EXPECT overrides),
# one per line: "<kind> <target> <expected> | <the host-side fix>", # for
# comments. Kinds: sysctl <name> <value>; nonempty <file>; sshcontrolpath
# <alias> %n (ssh -G <alias> prints a ControlPath holding the alias, so two
# aliases of one host never share a socket); http <url> <status>, the URL
# answers with that HTTP status within 5 s (LD-Q2); refused <host> <port>, a
# TCP connect from here fails within 5 s (RT4-Q1 (c)); jail <name>, the jail's
# name for the fix block, checking nothing. Prints each failure, then one block for the
# host: one jail -m line with every sysctl fix, then the other fixes. A read
# that fails is a failure. Exit 1 on any failure.
doctor() {
  f=${TEAM_EXPECT:-$here/expect}
  [ -f "$f" ] && [ -r "$f" ] || die "doctor: cannot read $f"
  jail='<jail>' jfix='' ofix='' n=0 bad=0
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in '' | '#'*) continue ;; esac
    fix=$(printf '%s' "${line#*|}" | sed 's/^ *//; s/ *$//')
    case $line in *'|'*) ;; *) fix='' ;; esac
    set -f
    # shellcheck disable=SC2086 # split the spec into its words
    set -- ${line%%|*}
    set +f
    kind=${1:-} target=${2:-} want=${3:-}
    # shellcheck disable=SC2088 # a literal ~/ in the file, expanded here
    case $target in '~/'*) target=$HOME/${target#'~/'} ;; esac
    got='' ok=0
    case $kind in
    jail) jail=$target; continue ;;
    sysctl)
      got=$(sysctl -n "$target" 2>&1) && [ "$got" = "$want" ] && ok=1 ;;
    nonempty)
      if [ -s "$target" ] && [ -r "$target" ]; then ok=1
      elif [ -e "$target" ] && [ -r "$target" ]; then got=empty
      else got='missing or unreadable'; fi ;;
    sshcontrolpath)
      if cfg=$(ssh -G "$target" 2>&1); then
        got=$(printf '%s\n' "$cfg" | awk '$1 == "controlpath" { print $2 }')
        case $got in *"$target"*) ok=1 ;; esac
      else
        got="ssh -G failed: $(printf '%s' "$cfg" | head -1)"
      fi ;;
    http)
      rc=0
      got=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$target" 2> /dev/null) || rc=$?
      if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then ok=1
      elif [ "$rc" != 0 ]; then got="no answer (curl exit $rc)"
      fi ;;
    refused)
      # Held only when nc tried the connect and says it failed; a port or an
      # address nc rejects, or no nc, is a failure (CO-Q1). -n: an IP address
      # only, no DNS; timeout 6 bounds the whole probe.
      case $want in '' | *[!0-9]*) got="port '$want' is not a number" ;; esac
      if [ -z "$got" ] && { [ "$want" -lt 1 ] || [ "$want" -gt 65535 ]; }; then got="port $want out of range"; fi
      if [ -n "$got" ]; then :
      elif ! command -v nc > /dev/null 2>&1; then got='no nc to try the connect'
      else
        rc=0
        out=$(timeout 6 nc -v -n -z -w 5 "$target" "$want" 2>&1) || rc=$?
        case $rc:$out in
        0:*) got=connected ;;
        *"connect to $target port $want "*" failed:"*) ok=1 ;;
        *) got="no connect tried (exit $rc): $(printf '%s' "$out" | head -1)" ;;
        esac
      fi
      want="port $want refused" ;;
    *) got="unknown kind '$kind'" ;;
    esac
    n=$((n + 1))
    [ $ok = 1 ] && continue
    bad=$((bad + 1))
    echo "FAIL $kind $target: expected ${want:-non-empty}, got ${got:-nothing}"
    case $kind in
    sysctl) jfix="$jfix $fix" ;;
    nonempty) ofix="$ofix$fix, and persist it in the host's fstab$cr" ;;
    *) ofix="$ofix$fix$cr" ;;
    esac
  done < "$f"
  if [ $bad = 0 ]; then echo "doctor: all $n held ($f)"; return 0; fi
  echo
  echo "On the host:"
  [ -z "$jfix" ] || echo "  doas jail -m name=$jail$jfix   (and persist them in the host's jail.conf)"
  printf '%s' "$ofix" | tr '\r' '\n' | sed 's/^/  /'
  echo "doctor: $bad of $n failed"
  return 1
}

# selftest: the team-fix test, on a separate tmux server (-L teamtest) with a
# spool, registry and pi session directory of its own. Real pi panes (no tools,
# no session) check the input-box detection; the test submits four one-line
# prompts to the model. spawn and revive run a stub in place of pi.
st_ok() { echo "ok   $*"; }
st_bad() { echo "FAIL $*"; st_fails=$((st_fails + 1)); }
check() { # description command...
  d=$1; shift
  if "$@"; then st_ok "$d"; else st_bad "$d"; fi
}
waitfor() { # seconds command...
  n=$1; shift
  while [ "$n" -gt 0 ]; do
    "$@" && return 0
    sleep 1; n=$((n - 1))
  done
  return 1
}
screen() { tmux capture-pane -p -J -t "$1"; }
has() { screen "$1" | grep -qF -- "$2"; }
lacks() { ! has "$@"; }
holds_text() { input_box "$1" > /dev/null && ! input_empty "$1"; }
queued() { # target count
  want=$2
  set -- "$spool/$1"/q/*
  if [ -f "$1" ]; then [ $# -eq "$want" ]; else [ "$want" -eq 0 ]; fi
}
failed_any() { for f in "$spool/$1"/failed/*; do [ -f "$f" ] && return 0; done; return 1; }
refused() { ! sh "$self" "$@" > /dev/null 2>&1; }
prints_line() { # line command...: the command prints exactly this line among its output
  want=$1; shift
  sh "$self" "$@" 2>&1 | grep -qxF -- "$want"
}
not_prints() { # text command...
  want=$1; shift
  ! sh "$self" "$@" 2>&1 | grep -qF -- "$want"
}
prints_nothing() { [ -z "$(sh "$self" "$@" 2>&1)" ]; }
waiting_unread() { # waiting against a tmux server that does not run (CO-Q7)
  out=$(TEAM_TMUX=teamtest-none sh "$self" waiting 2>&1) && return 1
  printf '%s\n' "$out" | grep -qF "waiting: cannot read the tmux server's windows"
}
refused_with() { # text command...
  want=$1; shift
  out=$(sh "$self" "$@" 2>&1) && return 1
  printf '%s\n' "$out" | grep -qF -- "$want"
}
in_order() { # pane text...
  s=$(screen "$1"); shift; last=0
  for x; do
    l=$(printf '%s\n' "$s" | grep -nF -- "$x" | head -1 | cut -d: -f1)
    [ -n "$l" ] && [ "$l" -gt "$last" ] || return 1
    last=$l
  done
}
status_shows_failed() { sh "$self" status | grep -q '^FAILED to-agent/failed/'; }
status_shows_queued() { sh "$self" status | grep -q '^QUEUED lead [0-9][0-9]*m: selftest report one'; }
status_says_box_held() { sh "$self" status | grep -q '^QUEUED lead .*input box holds text'; }
status_flags_held() { sh "$self" status | grep -q "^$1 .*\[input box holds text\]"; }
deliverer_alive() { # target
  p=$(cat "$spool/$1/deliver.lock/pid" 2> /dev/null) && kill -0 "$p" 2> /dev/null
}
status_flags_no_deliverer() { sh "$self" status | grep -q "^QUEUED $1 .*no deliverer"; }
no_deliverer() { ! deliverer_alive "$1"; }
status_loud_no_deliverer() { sh "$self" status | grep -q "^NO DELIVERER for $1: 1 message(s) queued"; }
spawned() { # name cwd task
  TEAM_ROLE=lead sh "$self" spawn "$@" > /dev/null 2>&1 && recorded_as "$1" "$2" "$3"
}
reports_as_text() { TEAM_QIDS_SKIP=1 TEAM_WAIT=3 sh "$self" report "$1" > /dev/null 2>&1; }
unregistered() { ! grep -q "^$1$tab" "$TEAM_QIDS"; }
status_has() { sh "$self" status | grep -qxF -- "$1"; }
status_lacks() { ! sh "$self" status | grep -q -- "$1"; }
wiki_flagged() { TEAM_WIKI=$1 sh "$self" status | grep -q '^WIKI last entry outside sources/ [0-9]*h ago'; }
wiki_silent() { ! TEAM_WIKI=$1 sh "$self" status | grep -q '^WIKI'; }
wiki_unreadable() { TEAM_WIKI=$1 sh "$self" status | grep -q '^WIKI last entry outside sources/: unreadable'; }
status_flags_unreadable() { sh "$self" status | grep -q "^$1 .*\[input box unreadable\]"; }
revive_leaves_alone() { sh "$self" revive a1 | grep -q 'left alone'; }
is_lead() { [ "$(lead_pane)" = "$1" ]; }
recorded_as() { # name cwd task
  [ "$(record "$1" | cut -f1-3)" = "$1$tab$2$tab$3" ] && [ -n "$(record "$1" | cut -f4)" ]
}
gone() { ! window_exists "$1" && ! record "$1" > /dev/null; }
st_cleanup() {
  for p in "$st_dir"/spool/*/deliver.lock/pid; do
    [ -f "$p" ] && kill "$(cat "$p")" 2> /dev/null
  done
  [ -z "${lpid:-}" ] || kill "$lpid" 2> /dev/null # st_doctor's listener (CO-Q5)
  tmux kill-server 2> /dev/null
  rm -rf "$st_dir"
}

# refresh, with box-pi in place of pi: it draws pi's input box, shows
# "Working" while $t/busy-<id> exists and text in its box while
# $t/typing-<id> does, and appends each line typed into it to $t/got-<id>.
# The selftest plays the seat: it writes the handoff the request names.
id_of() { record "$1" | cut -f4; }
got() { grep -qF -- "$2" "$t/got-$(id_of "$1")" 2> /dev/null; }
not_got() { ! got "$@"; }
ledgered() { # event seat [text]
  awk -F '\t' -v e="$1" -v s="$2" -v x="${3:-}" '$2 == e && $3 == s && index($0, x) { f = 1 } END { exit !f }' "$TEAM_LEDGER" 2> /dev/null
}
reported() { # text: queued for the lead, or typed into a box-pi pane (the lead's, once it is one)
  cat "$spool"/lead/q/* "$t"/got-* 2> /dev/null | grep -qF -- "$1"
}
reported_once() { # text: exactly one such report (RF-Q24); a queued report is a file with no final newline
  rcnt=$({
    for f in "$spool"/lead/q/*; do [ -f "$f" ] && grep -qF -- "$1" "$f" && echo queued; done
    cat "$t"/got-* 2> /dev/null | grep -F -- "$1"
  } | grep -c .) || true
  [ "${rcnt:-0}" -eq 1 ]
}
all_requested() { # one /refresh all request per recorded seat, polled (RF-Q24)
  [ "$(grep -c 'refresh-requested.*/refresh all' "$TEAM_LEDGER")" -eq "$(grep -c . "$TEAM_AGENTS")" ]
}
requested_path() { # seat -> the handoff path its request names
  sed -n 's/.*write your handoff to \([^ ]*\) .*/\1/p' "$t/got-$(id_of "$1")" 2> /dev/null | tail -1
}
handoff_asked() { [ -n "$(requested_path "$1")" ]; }
# Play the seat: write its answer at the path its last request names, if any
# (none after an earlier check failed: that check reports it).
answer() { # seat text
  ap=$(requested_path "$1"); [ -z "$ap" ] || printf '%s\n' "$2" > "$ap"
}
unlocked() { [ ! -d "$spool/refresh/$1.lock" ]; }
asks() { cnt=$(cat "$t/got-$(id_of "$1")" 2> /dev/null | grep -c 'write your handoff to') || true; echo "${cnt:-0}"; }
asked_more() { [ "$(asks "$1")" -gt "$2" ]; } # seat count
asked_anew() { # seat path: asked for a handoff at another path than this one
  p=$(requested_path "$1"); [ -n "$p" ] && [ "$p" != "$2" ]
}
quick() { # seconds command... : the command succeeds within that time
  lim=$1; shift
  s=$(date +%s); "$@" > /dev/null 2>&1 || return 1
  [ $(($(date +%s) - s)) -le "$lim" ]
}
refreshed() { # seat old-id: a new box-pi, named after the seat, holds the pane
  nid=$(id_of "$1")
  [ -n "$nid" ] && [ "$nid" != "$2" ] && has "$1" "box-pi TEAM_ROLE=unset id=$nid name=$1 $(date +%F) "
}
st_refresh() {
  cat > "$t/box-pi" <<'BOX'
#!/usr/bin/env bash
id=$2; name=''; shift 2
[ "${1:-}" = --name ] && { name=$2; shift 2; }
d=$(dirname "$0")
if [ $# -ge 1 ]; then p=yes; printf '%s\n' "$1" > "$d/prompt-$id"; else p=no; fi
# As ledger.ts does at session start (RF-Q21).
[ -z "${TMUX_PANE:-}" ] || tmux set -p -t "$TMUX_PANE" @session-id "$id"
r=$(printf '%.0s\342\224\200' $(seq 1 40))
stty -echo 2> /dev/null
pad=$(printf '%*s' $(($(tput lines 2> /dev/null || echo 24) - 7)) '' | tr ' ' '\n')
while :; do
  w=''; [ -f "$d/busy-$id" ] && w='Working...'
  b=''; [ -f "$d/typing-$id" ] && b='half a sentence'
  # One write per frame, so a capture never sees half a frame.
  printf '\033[H\033[2Jbox-pi TEAM_ROLE=%s id=%s name=%s prompt=%s\n%s\n%s\n%s\n%s\n%s\n' \
    "${TEAM_ROLE-unset}" "$id" "$name" "$p" "$pad" "$w" "$r" "$b" "$r"
  IFS= read -r -t 1 l && printf '%s\n' "$l" >> "$d/got-$id"
done
BOX
  chmod +x "$t/box-pi"
  TEAM_LEDGER=$t/ledger TEAM_HANDOFFS=$t/handoffs TEAM_START_WAIT=10
  export TEAM_LEDGER TEAM_HANDOFFS TEAM_START_WAIT
  mkdir -p "$t/handoffs"
  w='/refresh b1' src='lead pane 01:50'
  check "refresh refuses an unknown seat, naming it" refused_with "ghost" refresh ghost "$w" "$src"
  check "... and writes no ledger line" [ ! -s "$TEAM_LEDGER" ]
  check "refresh refuses empty words" refused refresh a2 "" "$src"
  check "refresh refuses a source without a time" refused refresh a2 "$w" "lead pane"
  sh "$self" _refresh ghost2 "$w" "$src" > /dev/null 2>&1 || true # no lock to write its pid into
  check "a run that stops unexpectedly logs it" ledgered refresh-failed ghost2 "step 0: stopped unexpectedly"
  check "... and reports it to the lead" reported "refresh ghost2: failed: step 0: the run stopped unexpectedly"
  TEAM_PI=$t/box-pi pi_cmd=$t/box-pi
  TEAM_ROLE=lead sh "$self" spawn b1 "$t" "$t/task" > /dev/null
  TEAM_ROLE=lead sh "$self" spawn b2 "$t" "$t/task" > /dev/null
  b1=$(id_of b1) b2=$(id_of b2)
  check "spawn names the session '<seat> <YYYY-MM-DD hh:mm>'" waitfor 10 has b1 "box-pi TEAM_ROLE=unset id=$b1 name=b1 $(date +%F) "
  : > "$t/busy-$b1"
  check "(setup: b1 shows busy)" waitfor 5 has b1 Working
  check "refresh returns at once while the seat is busy" quick 3 sh "$self" refresh b1 "$w" "$src"
  check "... and logs the request with the user's words" ledgered refresh-requested b1 "$w"
  check "a second refresh of the seat is refused while one runs" refused_with "already running since" refresh b1 "$w" "$src"
  check "a busy seat is deferred, and the reason logged" waitfor 10 ledgered refresh-deferred b1 busy
  check "... and is not asked for a handoff" not_got b1 "handoff"
  : > "$t/typing-$b1"
  check "(setup: b1 shows text in its box)" waitfor 5 has b1 'half a sentence'
  rm -f "$t/busy-$b1"
  check "a seat whose input box holds text is deferred, and the new reason logged" waitfor 10 ledgered refresh-deferred b1 "input box holds text"
  check "... and is not asked for a handoff" not_got b1 "handoff"
  rm -f "$t/typing-$b1"
  check "an idle seat is asked once for its handoff" waitfor 20 handoff_asked b1
  h=$(requested_path b1)
  check "... at a path in the handoff directory" [ "${h%/*}" = "$t/handoffs" ]
  [ -z "$h" ] || printf '# Handoff: seat b1, 18 Nov 2026 01:51\nselftest handoff\n' > "$h"
  check "after a valid handoff, a new pi with a new session and name holds the pane" waitfor 30 refreshed b1 "$b1"
  n1=$(id_of b1) task1=$(record b1 | cut -f3)
  check "... the registry names the new task file" [ "${task1%/*}" = "$t/handoffs" ]
  check "... whose first line is the Ceremony line, quoting the user" grep -qxF "Ceremony: none (the user, \"$w\", $(date '+%e %b %Y' | sed 's/^ //') 01:50)" "$task1"
  check "... and which points at the handoff" grep -qF "$h" "$task1"
  check "... the first message is the protocol header and the task file" grep -qF "You are the agent \`b1\`" "$t/prompt-$n1"
  check "... the ledger logs the handoff" ledgered handoff-written b1 "$h"
  check "(the lead gets a report)" waitfor 10 reported "refresh b1: done"
  check "... naming an old session without a name 'unnamed'" reported "; unnamed ($b1) stopped"
  sleep 3 # time for a second report, were one sent
  check "... and the lead gets exactly one report" reported_once "refresh b1: done"
  check "... and the lock is released" waitfor 10 unlocked b1
  c=$(asks b1)
  sh "$self" refresh b1 "$w" "$src" > /dev/null
  check "... (the next refresh asks again)" waitfor 20 asked_more b1 "$c"
  h=$(requested_path b1)
  [ -z "$h" ] || printf 'REFRESH-UNADVISABLE: a live run is under way\n' > "$h"
  check "a seat answering unadvisable is logged with its reason" waitfor 20 ledgered refresh-unadvisable b1 "a live run is under way"
  check "... reported to the lead" waitfor 10 reported "refresh b1: unadvisable: a live run is under way"
  check "... and keeps its session" [ "$(id_of b1)" = "$n1" ]
  check "(setup: b1's lock released)" waitfor 20 unlocked b1
  sh "$self" refresh b1 "$w" "$src" > /dev/null
  check "a refresh in the same minute asks at a new path, not the last one's" waitfor 20 asked_anew b1 "$h"
  answer b1 'REFRESH-UNADVISABLE: selftest'
  sh "$self" refresh b2 "$w" "$src" > /dev/null
  check "(b2 is asked)" waitfor 20 handoff_asked b2
  answer b2 'hello'
  check "a handoff with a wrong first line fails the refresh" waitfor 20 ledgered refresh-failed b2 "bad handoff"
  check "... reported to the lead" waitfor 10 reported "refresh b2: failed: bad handoff"
  check "... and the seat keeps its session" [ "$(id_of b2)" = "$b2" ]
  : > "$t/busy-$b2"
  check "(setup: b2 shows busy)" waitfor 5 has b2 Working
  check "(setup: b2's lock released)" waitfor 10 unlocked b2
  TEAM_WAIT=3 sh "$self" refresh b2 "$w" "$src" > /dev/null
  check "a seat still deferred after TEAM_WAIT fails the refresh" waitfor 20 ledgered refresh-failed b2 "still deferred: busy"
  check "... reported to the lead" waitfor 10 reported "refresh b2: failed: still deferred: busy"
  sh "$self" refresh a2 "$w" "$src" > /dev/null
  check "a pane with no input box is unadvisable" waitfor 20 ledgered refresh-unadvisable a2 "pane unreadable"
  check "(setup: b1's lock released)" waitfor 20 unlocked b1
  check "(setup: b2's lock released)" waitfor 20 unlocked b2
  : > "$t/busy-$n1"; rm -f "$t/busy-$b2"
  check "(setup: b1 shows busy)" waitfor 5 has b1 Working
  check "(setup: b2 shows idle)" waitfor 5 lacks b2 Working
  c1=$(asks b1) c2=$(asks b2)
  TEAM_WAIT=30 sh "$self" refresh all "/refresh all" "$src" > /dev/null
  check "all runs one refresh per recorded seat" waitfor 10 all_requested
  check "... one seat deferred does not hold another" waitfor 20 asked_more b2 "$c2"
  check "... the deferred one is not asked" not_got b1 "/refresh all"
  rm -f "$t/busy-$n1"
  answer b2 'REFRESH-UNADVISABLE: selftest'
  check "... the deferred one is asked once idle" waitfor 20 asked_more b1 "$c1"
  answer b1 'REFRESH-UNADVISABLE: selftest'
  check "(setup: b1's lock released)" waitfor 20 unlocked b1
  check "(setup: b2's lock released)" waitfor 20 unlocked b2
  tmux set -w -t "$(seat_pane b1)" @ctx 36.0
  tmux set -w -t "$(seat_pane b2)" @ctx 33.0
  c1=$(asks b1)
  out=$(sh "$self" refresh b1 b2 --min 35 "/refresh b1 b2 --min 35" "$src" 2>&1)
  check "refresh with a threshold skips a seat below it, naming its percentage" eval 'printf "%s\n" "$out" | grep -qxF "refresh of b2 skipped: context 33.0% is below 35%"'
  check "... and refreshes a seat above it" waitfor 10 ledgered refresh-requested b1 "/refresh b1 b2 --min 35"
  check "... and logs no request for the skipped one" eval '! ledgered refresh-requested b2 "/refresh b1 b2 --min 35"'
  check "(setup: b1 asked)" waitfor 20 asked_more b1 "$c1"
  answer b1 'REFRESH-UNADVISABLE: selftest'
  check "(setup: b1's lock released)" waitfor 20 unlocked b1
  tmux set -wu -t "$(seat_pane b2)" @ctx
  out=$(sh "$self" refresh b2 --min 35 "/refresh b2 --min 35" "$src" 2>&1)
  check "a seat whose context is unknown is skipped, saying so" eval 'printf "%s\n" "$out" | grep -qF "refresh of b2 skipped: context unknown"'
  check "... and nothing is requested" eval '! ledgered refresh-requested b2 "/refresh b2 --min 35"'
  tmux set -w -t "$(seat_pane b2)" @ctx 35.2
  out=$(sh "$self" refresh b2 --min 35.5 "/refresh b2 --min 35.5" "$src" 2>&1)
  check "a decimal threshold is accepted" eval 'printf "%s\n" "$out" | grep -qxF "refresh of b2 skipped: context 35.2% is below 35.5%"'
  check "a trailing number without --min is a seat name, refused when unrecorded" refused_with "35 is not recorded" refresh b2 35 "/refresh b2 35" "$src"
  tmux set -w -t "$(seat_pane b2)" @ctx 35.0
  c2=$(asks b2)
  out=$(sh "$self" refresh b2 --min 35 "/refresh b2 --min 35 equal" "$src" 2>&1)
  check "a seat equal to the threshold is refreshed (the operator, 26 Nov 23:35)" waitfor 10 ledgered refresh-requested b2 "/refresh b2 --min 35 equal"
  check "(setup: b2 asked)" waitfor 20 asked_more b2 "$c2"
  answer b2 'REFRESH-UNADVISABLE: selftest'
  check "(setup: b2's lock released)" waitfor 20 unlocked b2
  tmux respawn-pane -k -t "$lp" "$t/box-pi --session-id lead0"
  sh "$self" refresh lead "/refresh lead" "$src" > /dev/null
  check "the lead is asked for its handoff" waitfor 30 grep -qs "write your handoff to $t/handoffs/handoff-.*-lead.md" "$t/got-lead0"
  hl=$(sed -n 's/.*write your handoff to \([^ ]*\) .*/\1/p' "$t/got-lead0" | tail -1)
  [ -z "$hl" ] || printf '# Handoff: seat lead, 18 Nov 2026 01:52\n' > "$hl"
  check "the new lead runs with TEAM_ROLE=lead" waitfor 30 has "$lp" "box-pi TEAM_ROLE=lead id="
  check "... its pane keeps @role=lead" is_lead "$lp"
  nl=$(screen "$lp" | sed -n 's/^box-pi TEAM_ROLE=lead id=\([^ ]*\) .*/\1/p')
  check "... its first message names the chief of staff and the handoff" grep -qF "chief of staff" "$t/prompt-$nl"
  c2=$(asks b2)
  TEAM_PI=$t/no-such-pi sh "$self" refresh b2 "$w" "$src" > /dev/null
  check "(b2 is asked)" waitfor 20 asked_more b2 "$c2"
  answer b2 '# Handoff: seat b2, 18 Nov 2026 01:53'
  check "no pi input box after the respawn fails the refresh" waitfor 40 ledgered refresh-failed b2 "no pi in pane"
  check "... reported with both session ids" waitfor 10 reported "$b2"
  check "the new lead leaves a shell when it exits" lead_shell_left "$nl"
}
lead_shell_left() { # new lead id
  pkill -f "box-pi --session-id $1" || return 1
  waitfor 5 [ "$(tmux display -p -t "$lp" '#{pane_current_command}')" = bash ]
}

# doctor's refused kind (RT4-Q1 (c)): a real listener on 127.0.0.1 that
# answers, and a port nothing listens on.
st_doctor() {
  dport=47431 cport=47432
  for p in "$dport" "$cport"; do
    if nc -z -w 1 127.0.0.1 "$p" 2> /dev/null; then
      st_bad "doctor: 127.0.0.1:$p already answers before the test listens; free it and rerun"
      return
    fi
  done
  nc -k -l 127.0.0.1 "$dport" > /dev/null 2>&1 &
  lpid=$!
  waitfor 5 nc -z -w 1 127.0.0.1 "$dport" || st_bad "doctor: the listener on 127.0.0.1:$dport never answered"
  printf 'refused 127.0.0.1 65536 | x\n' > "$t/expect-badport"
  printf 'refused nosuch.invalid %s | x\n' "$cport" > "$t/expect-name"
  export TEAM_EXPECT="$t/expect-badport"
  check "doctor's refused fails on a port nc rejects, never taking it as refused" refused_with "FAIL refused 127.0.0.1: expected port 65536 refused, got port 65536 out of range" doctor
  export TEAM_EXPECT="$t/expect-name"
  check "doctor's refused fails on a host name, which it does not resolve" refused_with "FAIL refused nosuch.invalid: expected port $cport refused, got no connect tried" doctor
  printf 'refused 127.0.0.1 %s | nothing to do\n' "$cport" > "$t/expect-closed"
  printf 'jail j\nrefused 127.0.0.1 %s | take down what answers there\n' "$dport" > "$t/expect-open"
  export TEAM_EXPECT="$t/expect-closed"
  check "doctor's refused holds on a port nothing answers" sh "$self" doctor
  export TEAM_EXPECT="$t/expect-open"
  check "doctor's refused fails on a port that answers" refused_with "FAIL refused 127.0.0.1: expected port $dport refused, got connected" doctor
  check "... and prints its fix" refused_with "  take down what answers there" doctor
  unset TEAM_EXPECT
  kill "$lpid" 2> /dev/null
  lpid=''
}

selftest() {
  [ -z "${TEAM_TMUX:-}" ] || die "selftest: TEAM_TMUX is set"
  TEAM_TMUX=teamtest
  ! tmux has-session 2> /dev/null || die "selftest: a tmux -L teamtest server is running (tmux -L teamtest kill-server)"
  st_dir=$(mktemp -d "${TMPDIR:-/tmp}/teamtest.XXXXXX")
  st_fails=0
  TEAM_SPOOL=$st_dir/spool TEAM_AGENTS=$st_dir/agents TEAM_POLL=1
  PI_CODING_AGENT_SESSION_DIR=$st_dir/sessions TEAM_QIDS=$st_dir/qids TEAM_CHECKOUTS=$st_dir/checkouts
  export TEAM_TMUX TEAM_SPOOL TEAM_AGENTS TEAM_POLL PI_CODING_AGENT_SESSION_DIR TEAM_QIDS TEAM_CHECKOUTS
  unset TMUX TMUX_PANE TEAM_ROLE TEAM_WAIT TEAM_PI
  spool=$TEAM_SPOOL agents=$TEAM_AGENTS poll=1
  trap st_cleanup EXIT
  trap 'exit 1' INT TERM HUP

  # Delivery, as the team-fix test of 12 Nov: real pi panes.
  t=$st_dir pi_real='pi --no-session --no-tools -na'
  tmux new-session -d -s st -n lead -x 160 -y 45 -c "$t" "$pi_real"
  tmux new-window -d -t st: -n agent -c "$t" "$pi_real"
  lp=$(tmux display -p -t st:lead '#{pane_id}')
  ap=$(tmux display -p -t st:agent '#{pane_id}')
  tmux set -p -t "$lp" @role lead
  if waitfor 60 input_empty "$lp" && waitfor 30 input_empty "$ap"; then
    st_ok "an empty input box is found in a real pi pane"
  else
    st_bad "no empty input box in a real pi pane: has pi's TUI changed? The lead pane's bottom lines:"
    screen "$lp" | tail -8
    return 1
  fi
  # waiting: the rows from the windows' options (RT4-Q5 (b)).
  # @status-open is the STATUS line's open=; @open, the tab's, is unset as the
  # operator types (CO-Q4).
  tmux set -w -t "$ap" @status-open 2 && tmux set -w -t "$ap" @worst high && tmux set -w -t "$ap" @ask 'CO-Q1 | CO-Q2'
  tmux set -w -t "$lp" @status-open 1
  check "waiting prints a seat with open questions, its count, worst and ask, @open unset" prints_line '| agent | 2 open, worst high: CO-Q1 \| CO-Q2 |' waiting
  check "... and leaves the lead's own window out" not_prints 'lead' waiting
  tmux set -w -t "$ap" @status-open 0 && tmux set -w -t "$ap" @state waiting-for-PM && tmux set -w -t "$ap" @ask 'a read of the diff'
  check "waiting names a seat waiting on the operator with open=0 as 'no ID'" prints_line '| agent | no ID: a read of the diff |' waiting
  # A seat not reloaded since @status-open came (the lead, 27 Nov 22:59): no
  # "no ID" row on its missing count.
  tmux set -wu -t "$ap" @status-open && tmux set -w -t "$ap" @open 1
  check "waiting takes @open when @status-open is unset" prints_line '| agent | 1 open, worst high: a read of the diff |' waiting
  tmux set -wu -t "$ap" @open
  check "waiting says the count is unknown when both are unset, not 'no ID'" prints_line '| agent | open unknown: a read of the diff |' waiting
  tmux set -w -t "$ap" @open 0
  check "... and an @open of 0 alone is not 'no ID'" prints_line '| agent | open unknown: a read of the diff |' waiting
  tmux set -wu -t "$ap" @open
  tmux set -wu -t "$ap" @state && tmux set -wu -t "$ap" @ask && tmux set -wu -t "$ap" @worst && tmux set -wu -t "$ap" @status-open && tmux set -wu -t "$lp" @status-open
  check "waiting prints nothing when no seat waits" prints_nothing waiting
  check "waiting exits 1 when it cannot read tmux, naming it" waiting_unread
  check "send refuses a text claiming a user's go, showing go's usage" refused_with '"<pane> <time>" "<instruction>"' send agent "Lead: the user's go, lead pane, now ('yes'): x"
  check "... and one claiming it in go's own form" refused send agent "Lead: the user's go ('yes', lead pane 12:00), relayed 12:01: x"
  check "... and one claiming it with a colon" refused send agent "Lead: the user's go: yes"
  check "go refuses empty words" refused go agent "" "lead pane 12:00" "x"
  check "go refuses '...'" refused go agent "..." "lead pane 12:00" "x"
  check "go refuses '…'" refused go agent " … " "lead pane 12:00" "x"
  half="selftest: a half-typed line of the user; reply with only OK"
  tmux send-keys -t "$lp" -l -- "$half"
  check "an input box holding text counts as not empty" waitfor 5 holds_text "$lp"
  sh "$self" report "selftest report one: reply with only OK" > /dev/null
  sh "$self" report "selftest report two: reply with only OK" > /dev/null
  check "go refuses a source without a time" refused go agent "yes" "lead pane" "x"
  sh "$self" go agent "go ahead" "lead pane 12:00" "selftest go: reply with only OK" > /dev/null
  check "go is delivered into an empty box, quoting the user's words, source and time" waitfor 30 has "$ap" "the user's go ('go ahead', lead pane 12:00), relayed "
  check "go quotes the instruction" has "$ap" ": selftest go: reply with only OK"
  check "send passes a text that mentions the user's go without claiming it" sh "$self" send agent "selftest send: ask the user's go for the write in your pane; reply with only OK"
  check "... and delivers it" waitfor 90 has "$ap" "selftest send: ask the user's go for the write in your pane"
  sleep 4
  check "reports wait while the lead's box holds text" queued lead 2
  check "status lists them as QUEUED, with their age" status_shows_queued
  check "... saying the lead's input box holds text" status_says_box_held
  check "... and are not typed" lacks "$lp" "selftest report one"
  tmux send-keys -t "$lp" -l -- "$cr" # the user submits the line
  check "the reports are delivered once the user's line is submitted" waitfor 120 queued lead 0
  check "... in order, after the user's line" waitfor 60 in_order "$lp" "$half" "selftest report one" "selftest report two"
  waitfor 60 input_empty "$ap" || true
  tmux send-keys -t "$ap" -l -- "selftest: the user types in the agent pane"
  check "status flags an agent whose input box holds text" waitfor 5 status_flags_held agent
  # timeout(1), a process reaper on FreeBSD, kills every descendant of its
  # command when it fires (TD-Q1, 17 Nov).
  # The caller outlives timeout's limit, as a long command around team.sh
  # does, so timeout fires and kills what it reaps.
  TEAM_WAIT=8 timeout 3 sh -c 'sh "$1" send agent "selftest: sent under timeout" > /dev/null 2>&1; sleep 10' _ "$self" || true
  check "a deliverer started by a send under timeout(1) outlives it" deliverer_alive to-agent
  tmux send-keys -t "$ap" -l -- "$cr" # the user submits the line
  check "... and delivers the message once the box is empty" waitfor 30 has "$ap" "selftest: sent under timeout"
  waitfor 60 input_empty "$ap" || true
  # The lead's "team.sh send … | head -1": the reader is gone before send
  # prints, so its first write meets a closed pipe (19 Nov). The previous
  # deliverer is gone first, so only this send's own deliverer can deliver.
  check "(setup: no deliverer for agent is alive)" waitfor 10 no_deliverer to-agent
  sh -c 'sleep 1; exec sh "$1" send agent "selftest: sent into a closed pipe; reply with only OK"' _ "$self" | true
  check "a send whose caller stopped reading still starts a deliverer, which delivers" waitfor 30 has "$ap" "selftest: sent into a closed pipe"
  waitfor 60 input_empty "$ap" || true
  tmux send-keys -t "$ap" -l -- "selftest: the user types in the agent pane again"
  waitfor 5 holds_text "$ap" || true
  mkdir -p "$spool/to-ghost/q" && printf 'selftest: nobody delivers this\n' > "$spool/to-ghost/q/000000001"
  check "status flags a queue with no deliverer" status_flags_no_deliverer to-ghost
  check "... loudly, on a line of its own" status_loud_no_deliverer to-ghost
  rm -rf "$spool/to-ghost"
  TEAM_WAIT=3 sh "$self" send agent "selftest: a message that times out" > /dev/null
  check "a message waiting past TEAM_WAIT moves to failed/" waitfor 20 failed_any to-agent
  check "status prints the failed message" status_shows_failed
  printf '2026-11-16 09:00:00 CET run: /w/tools/team.sh spawn lint-1 /w /w/t.md\nspawn: no Ceremony line\n2026-11-16 09:00:00 CET exit 1\n' > "$spool/cron.log"
  check "status flags a last cron run that exited non-zero" status_has "CRON lint-1 exit 1, 16 Nov 09:00: see $spool/cron.log"
  printf '2026-11-23 09:00:00 CET run: /w/tools/team.sh spawn lint-2 /w /w/t.md\n2026-11-23 09:00:01 CET exit 0\n' >> "$spool/cron.log"
  check "... and is silent once a later run succeeds" status_lacks CRON
  wk=$(mktemp -d "${TMPDIR:-/tmp}/team-wiki.XXXXXX")
  git -C "$wk" init -q && echo i > "$wk/index.md" && git -C "$wk" add index.md &&
    GIT_AUTHOR_DATE='2026-11-01T09:00:00' GIT_COMMITTER_DATE='2026-11-01T09:00:00' git -C "$wk" -c user.name=t -c user.email=t@t commit -q -m old
  mkdir -p "$wk/sources" && echo s > "$wk/sources/s.md" && git -C "$wk" add sources && git -C "$wk" -c user.name=t -c user.email=t@t commit -q -m src
  check "status flags a wiki whose last entry outside sources/ is a day old or more, a newer sources/ commit aside" wiki_flagged "$wk"
  echo j >> "$wk/index.md" && git -C "$wk" -c user.name=t -c user.email=t@t commit -qam new
  check "... and is silent after a fresh entry" wiki_silent "$wk"
  mkdir -p "$wk/sub" && echo i > "$wk/sub/index.md" && git -C "$wk" add sub &&
    GIT_AUTHOR_DATE='2026-11-01T09:00:00' GIT_COMMITTER_DATE='2026-11-01T09:00:00' git -C "$wk" -c user.name=t -c user.email=t@t commit -q -m sub
  check "... and calls a wiki folder inside another repository unreadable" wiki_unreadable "$wk/sub"
  rm -rf "$wk"
  check "send publishes the question-ID registry to pi panes" [ "$(tmux show -gv @team-qids)" = "$TEAM_QIDS" ]
  check "... and its own path, for /draft's relay" [ "$(tmux show -gv @team-sh)" = "$self" ]
  printf 'XX-Q1\tother\t14 Nov 2026\n' > "$TEAM_QIDS"
  check "report refuses a ❓ ID registered to another seat, naming it" refused_with "XX-Q1 is other's (14 Nov 2026)" report "a1: ❓ XX-Q1 – taken?"
  check "report with TEAM_QIDS_SKIP=1 relays quoted IDs as text" reports_as_text "a1: /draft quoting ❓ XX-Q1 – taken? and ❓ XX-Q9"
  check "... and registers none of them" unregistered XX-Q9
  TEAM_WAIT=3 sh "$self" report "a1: ❓ XX-Q2 – new? reply with only OK" > /dev/null
  check "report registers a new ❓ ID to its seat" grep -q "^XX-Q2${tab}a1${tab}" "$TEAM_QIDS"

  # spawn, retire and revive, with a stub for pi.
  TEAM_PI=$t/stub-pi pi_cmd=$t/stub-pi
  export TEAM_PI
  cat > "$TEAM_PI" <<'STUB'
#!/bin/sh
if [ $# -ge 3 ]; then p=yes; else p=no; fi
echo "stub-pi TEAM_ROLE=${TEAM_ROLE-unset} $1 $2 prompt=$p"
exec sleep 3600
STUB
  chmod +x "$TEAM_PI"
  printf 'Ceremony: none (the user, "selftest", 14 Nov 11:29)\nselftest task\n' > "$t/task"
  TEAM_ROLE=lead sh "$self" spawn a1 "$t" "$t/task" > /dev/null
  TEAM_ROLE=lead sh "$self" spawn a2 "$t" "$t/task" > /dev/null
  id1=$(record a1 | cut -f4) id2=$(record a2 | cut -f4)
  check "spawn records name, cwd, task file and session id" recorded_as a1 "$t" "$t/task"
  check "spawn starts pi with the session id and the prompt, without TEAM_ROLE" waitfor 10 has st:a1 "stub-pi TEAM_ROLE=unset --session-id $id1 prompt=yes"
  check "session ids differ" [ "$id1" != "$id2" ]
  mkdir -p "$t/sessions/--x--"
  : > "$t/sessions/--x--/2026-11-13T00-00-00-000Z_$id1.jsonl"
  tmux kill-server # a tmux restart: a1 has a saved session, a2 none
  sleep 1
  tmux new-session -d -s st -n lead -x 160 -y 45 -c "$t" "sleep 3600"
  lp=$(tmux display -p -t st:lead '#{pane_id}')
  check "spawn refuses a recorded name" refused spawn a1 "$t" "$t/task"
  : > "$t/empty"
  check "spawn refuses an empty task file" refused_with "is missing or empty" spawn a3 "$t" "$t/empty"
  check "... and records nothing" gone a3
  printf 'selftest task\nCeremony: script (the user, "yes", 14 Nov 11:29)\n' > "$t/no-ceremony"
  check "spawn refuses a task file whose first line names no ceremony" refused_with "no Ceremony line" spawn a4 "$t" "$t/no-ceremony"
  check "... and records nothing" gone a4
  n=5
  for tier in research write-up retro docs vg; do
    printf 'Ceremony: %s (the user, "yes", 17 Nov 11:44)\nselftest %s task\n' "$tier" "$tier" > "$t/$tier-task"
    check "spawn accepts a task file sized $tier" spawned "a$n" "$t" "$t/$tier-task"
    n=$((n + 1))
  done
  TMUX_PANE=$lp sh "$self" revive --all > /dev/null
  check "revive re-sets @role=lead on the lead pane" is_lead "$lp"
  check "revive reopens a saved session, with no prompt" waitfor 10 has st:a1 "stub-pi TEAM_ROLE=unset --session-id $id1 prompt=no"
  check "revive restarts an agent with no saved session from its task file" waitfor 10 has st:a2 "--session-id $id2 prompt=yes"
  check "revive leaves a running agent alone" revive_leaves_alone
  check "status flags an agent whose input box cannot be read" status_flags_unreadable a1
  check "retire refuses a seat with no check-out, naming where it goes" refused_with "$TEAM_CHECKOUTS/" retire a1
  check "... and leaves its window and record" recorded_as a1 "$t" "$t/task"
  mkdir -p "$TEAM_CHECKOUTS" && printf '# Check-out: a1 (18 Nov 2026)\n' > "$TEAM_CHECKOUTS/2026-11-18-a1.md"
  sh "$self" retire a1 > /dev/null || true # the next check reads the result
  check "retire closes the window and drops the record" gone a1
  check "... and leaves the others" recorded_as a2 "$t" "$t/task"
  check "revive refuses an unrecorded name" refused revive a1
  printf '# Check-out: x-a5 (18 Nov 2026)\n' > "$TEAM_CHECKOUTS/2026-11-18-x-a5.md"
  : > "$TEAM_CHECKOUTS/2026-11-18-a6.md"
  check "retire refuses an empty check-out, saying it is empty" refused_with "2026-11-18-a6.md is empty" retire a6
  printf 'x\n' > "$TEAM_CHECKOUTS/2026-11-17-a6.md" && chmod 000 "$TEAM_CHECKOUTS/2026-11-17-a6.md"
  rm -f "$TEAM_CHECKOUTS/2026-11-18-a6.md"
  if [ "$(id -u)" != 0 ]; then
    check "retire refuses an unreadable check-out, saying it cannot read it" refused_with "cannot read $TEAM_CHECKOUTS/2026-11-17-a6.md" retire a6
  fi
  chmod 644 "$TEAM_CHECKOUTS/2026-11-17-a6.md" && rm -f "$TEAM_CHECKOUTS/2026-11-17-a6.md"
  check "retire takes no other seat's check-out for its own (x-a5 is not a5)" refused retire a5
  check "retire --no-checkout refuses an empty reason" refused retire a5 --no-checkout " "
  check "... and retires nothing" recorded_as a5 "$t" "$t/research-task"
  sh "$self" retire a5 --no-checkout "selftest: never started" > /dev/null || true # the next check reads the result
  check "retire --no-checkout with a reason retires" gone a5
  check "... and logs the reason" grep -q 'retired a5 without a check-out: selftest: never started' "$spool/log"

  st_refresh
  st_doctor

  if [ "$st_fails" -eq 0 ]; then echo "selftest passed"; else echo "selftest: $st_fails failed"; return 1; fi
}

usage() { awk 'NR > 1 && /^#/ { print; next } NR > 1 { exit }' "$self" >&2; exit 2; }

case ${1:-} in
spawn)
  [ $# -eq 4 ] || { echo "usage: $0 spawn <name> <cwd> <task file>" >&2; exit 2; }
  publish_qids
  name=$2
  case $name in '' | *"$tab"* | *[!A-Za-z0-9._-]*) die "spawn: bad name '$name'" ;; esac
  cwd=$(cd "$3" && pwd) || exit 1
  task_ok "$4" || die "spawn: task file $4 is missing or empty"
  ceremony_ok "$4" ||
    die "spawn: task file $4 has no Ceremony line first: Ceremony: <research|write-up|retro|docs|vg|checklist|script|full|none> (the user, \"<words>\", <date> hh:mm)"
  task=$(cd "$(dirname "$4")" && pwd)/$(basename "$4")
  ! window_exists "$name" || die "window $name exists"
  ! record "$name" > /dev/null || die "$name is recorded in $agents: team.sh revive or retire it"
  id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  sname=$(session_name "$name")
  open_window "$name" "$cwd" "$id" "$sname" "$(compose_prompt "$name" "$task")"
  registry_lock || die "spawn: cannot lock $agents.lock; $name started but not recorded: team.sh retire $name"
  printf '%s\t%s\t%s\t%s\n' "$name" "$cwd" "$task" "$id" >> "$agents"
  rm -rf "$agents.lock"
  ledger_add spawn "$name" "$id" "$sname" "$task"
  [ -z "$ledger_err" ] || say_err "$ledger_err"
  echo "spawned $name (session $id)"
  ;;
send)
  [ $# -eq 3 ] || { echo "usage: $0 send <name> <text>" >&2; exit 2; }
  # The claim forms only ("the user's go (", ", " or ":"); a mention passes (RT4-Q8 (a)).
  if printf '%s' "$3" | grep -qiE "user('|’)s go( \(|,|:)"; then
    die "send: the text claims a user's go; use team.sh go <name> \"<the user's exact words>\" \"<pane> <time>\" \"<instruction>\""
  fi
  enqueue "to-$2" "$3"
  ;;
go)
  [ $# -eq 5 ] || { echo "usage: $0 go <name> \"<the user's exact words>\" \"<pane> <time>\" \"<instruction>\"" >&2; exit 2; }
  [ -n "$(printf '%s' "$3" | sed 's/…//g' | tr -d ' \t\n.')" ] ||
    die "go: the user's words are empty or '...'; quote them exactly"
  printf '%s' "$4" | grep -Eq '[^ ].* [0-2]?[0-9]:[0-5][0-9]' ||
    die "go: say where and when the user gave the go, e.g. \"prod-net pane 22:57\" (the stamp on their message)"
  [ -n "$(printf '%s' "$5" | tr -d ' \t\n')" ] || die "go: empty instruction"
  enqueue "to-$2" "Lead: the user's go ('$3', $4), relayed $(date '+%e %b %H:%M' | sed 's/^ //'): $5"
  ;;
report)
  [ $# -eq 2 ] || { echo "usage: $0 report <text>" >&2; exit 2; }
  [ "${TEAM_QIDS_SKIP:-}" = 1 ] || register_qids "$2"
  enqueue lead "$2"
  ;;
_deliver)
  deliver "$2"
  ;;
_box) # pane: show what the delivery check sees
  if box=$(input_box "$2"); then
    printf '%s\n' "$box" | sed 's/^/| /'
    if input_empty "$2"; then echo empty; else echo 'holds text'; fi
  else
    echo 'no input box'
  fi
  ;;
waiting)
  # From the windows' options, which only each seat's last STATUS line sets
  # (open-questions.ts): @status-open, @worst, @state and @ask; not @open,
  # which the operator's typing clears (CO-Q4). The lead's window is left out.
  # A failed read of tmux exits 1, never an empty table (CO-Q7).
  lead=$(lead_pane)
  leadwin=''
  [ -z "$lead" ] || leadwin=$(tmux display -p -t "$lead" '#{window_id}')
  # A unit separator, not a tab: read joins runs of a whitespace IFS, so an
  # empty field would shift the rest.
  us=$(printf '\037')
  # A seat whose extension predates @status-open (not reloaded since 2.20.0),
  # or with no STATUS line since, has none: its count is @open if set, else
  # unknown; only an explicit @status-open of 0 makes a "no ID" row.
  rows=$(tmux list-windows -a -F "#{window_id}$us#{window_name}$us#{@status-open}$us#{@open}$us#{@worst}$us#{@state}$us#{@ask}") ||
    die "waiting: cannot read the tmux server's windows"
  printf '%s\n' "$rows" |
    while IFS="$us" read -r wid name open tabopen worst state ask; do
      [ "$wid" = "$leadwin" ] && continue
      ask=$(printf '%s' "$ask" | sed 's/|/\\|/g')
      count=${open:-$tabopen} # the STATUS line's count, else the tab's (CO-Q16)
      if [ -n "$count" ] && [ "$count" -gt 0 ] 2> /dev/null; then
        echo "| $name | $count open${worst:+, worst $worst}${ask:+: $ask} |"
      elif [ "$state" != waiting-for-PM ]; then
        :
      elif [ "$open" = 0 ]; then
        echo "| $name | no ID: ${ask:-(no ask)} |"
      else
        echo "| $name | open unknown: ${ask:-(no ask)} |"
      fi
    done
  ;;
queue)
  for f in "$spool"/*/q/* "$spool"/*/failed/*; do
    [ -f "$f" ] && printf '%s: %s\n' "${f#"$spool"/}" "$(head -1 "$f" | cut -c1-100)"
  done
  true
  ;;
status)
  lead=$(lead_pane)
  leadwin=''
  if [ -n "$lead" ]; then
    leadwin=$(tmux display -p -t "$lead" '#{window_index}')
  else
    echo "no pane has @role=lead (team.sh revive sets it from the lead pane)"
  fi
  # First, loudly: a queue nothing will type until a deliverer starts.
  for d in "$spool"/*/q; do
    n=$(ls "$d" 2> /dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] || continue
    target=${d%/q}; target=${target##*/}
    dp=$(cat "$spool/$target/deliver.lock/pid" 2> /dev/null) && kill -0 "$dp" 2> /dev/null && continue
    echo "NO DELIVERER for $target: $n message(s) queued and nothing will type them; start one: tmux run-shell -b \"sh $(q "$self") _deliver $target >> $(q "$spool/log") 2>&1\""
  done
  tmux list-windows -F '#{window_index} #{window_name}' | while read -r idx name; do
    [ "$idx" = "$leadwin" ] && continue
    pane=$(tmux capture-pane -p -J -S -300 -t "$idx")
    line=$(printf '%s\n' "$pane" | grep -o 'STATUS seat=.*' | tail -1)
    flag=''
    busy "$idx" && flag='[busy] '
    if input_box "$idx" > /dev/null; then
      holds_text "$idx" && flag="${flag}[input box holds text] "
    else
      flag="${flag}[input box unreadable] "
    fi
    printf '%-16s %s%s\n' "$name" "$flag" "${line:-(no STATUS line)}"
  done
  for f in "$spool"/*/failed/*; do
    [ -f "$f" ] && printf 'FAILED %s: %s\n' "${f#"$spool"/}" "$(head -1 "$f" | cut -c1-100)"
  done
  now=$(date +%s)
  for f in "$spool"/*/q/*; do
    [ -f "$f" ] || continue
    target=${f#"$spool"/}
    age=$(mtime "$f") || age=''
    case $age in '' | *[!0-9]*) age='age unreadable' ;; *) age="$(((now - age) / 60))m" ;; esac
    held=''
    dp=$(cat "$spool/${target%%/*}/deliver.lock/pid" 2> /dev/null) && kill -0 "$dp" 2> /dev/null ||
      held=' (no deliverer: the next send or report to it starts one)'
    p=$(resolve "${target%%/*}" 2> /dev/null) || p=''
    if [ -n "$p" ]; then
      if ! input_box "$p" > /dev/null; then held="$held (its input box is unreadable)"
      elif holds_text "$p"; then held="$held (waits: its input box holds text)"
      fi
    fi
    printf 'QUEUED %s %s: %s%s\n' "${target%%/*}" "$age" "$(head -1 "$f" | cut -c1-80)" "$held"
  done
  cron_flag
  wiki_flag
  true
  ;;
refresh)
  [ $# -ge 4 ] || { echo "usage: $0 refresh <name>…|all|lead [--min <percent>] \"<the user's words>\" \"<pane> <time>\"" >&2; exit 2; }
  shift
  n=$# i=0 names='' words='' src='' threshold=''
  for a; do
    i=$((i + 1))
    if [ $i -le $((n - 2)) ]; then names="$names $a"
    elif [ $i -eq $((n - 1)) ]; then words=$a
    else src=$a; fi
  done
  # --min <percent> among the names is the context threshold (CS-Q90; AW-Q188 (c)):
  # a seat whose window's @ctx (open-questions.ts publishes it) is below it, or
  # unknown, is skipped. A decimal percent is accepted (AW-Q187).
  rest='' want=''
  for a in $names; do
    if [ "$want" = 1 ]; then threshold=$a want=''
    elif [ "$a" = --min ]; then want=1
    else rest="$rest $a"; fi
  done
  [ -z "$want" ] || die "refresh: --min needs a percentage, e.g. --min 35"
  if [ -n "$threshold" ]; then
    printf '%s' "$threshold" | grep -Eqx '[0-9]+(\.[0-9]+)?' &&
      awk -v t="$threshold" 'BEGIN { exit !(t + 0 <= 100) }' ||
      die "refresh: --min $threshold is not a percentage (0 to 100)"
    [ -n "$rest" ] || die "refresh: no seat named besides --min $threshold"
  fi
  names=$rest
  [ -n "$(printf '%s' "$words" | sed 's/…//g' | tr -d ' \t\n.')" ] ||
    die "refresh: the user's words are empty or '...'; quote them exactly"
  printf '%s' "$src" | grep -Eq '[^ ].* [0-2]?[0-9]:[0-5][0-9]$' ||
    die "refresh: say where and when the user asked, e.g. \"lead pane 01:50\" (the stamp on their message)"
  publish_qids
  seats=''
  for s in $names; do
    case $s in *[!A-Za-z0-9._-]*) die "refresh: bad name '$s'" ;; esac
    if [ "$s" = all ]; then
      [ -f "$agents" ] || die "refresh: no seat is recorded ($agents is absent)"
      all=$(cut -f1 "$agents") || die "refresh: cannot read $agents"
      [ -n "$all" ] || die "refresh: no seat is recorded in $agents"
      seats="$seats $all"
    else
      seats="$seats $s"
    fi
  done
  [ ! -e "$agents" ] || [ -r "$agents" ] || die "refresh: cannot read $agents; nothing started"
  for s in $seats; do
    p=$(seat_pane "$s") || die "refresh: cannot read tmux's panes; nothing started"
    if [ "$s" = lead ]; then
      [ -n "$p" ] || die "refresh: no pane has @role=lead; nothing started"
    else
      record "$s" > /dev/null || die "refresh: $s is not recorded in $agents; nothing started"
      [ -n "$p" ] || die "refresh: $s has no window; nothing started"
    fi
  done
  if [ -n "$threshold" ]; then
    kept=''
    for s in $seats; do
      c=$(tmux show -wv -t "$(seat_pane "$s")" @ctx 2> /dev/null) || c=''
      case $c in
      '' | *[!0-9.]* | *.*.*) say "refresh of $s skipped: context unknown (no @ctx on its window), threshold $threshold%" ;;
      *)
        if awk -v c="$c" -v t="$threshold" 'BEGIN { exit !(c + 0 < t + 0) }'; then
          say "refresh of $s skipped: context $c% is below $threshold%"
        else kept="$kept $s"; fi
        ;;
      esac
    done
    seats=$kept
    [ -n "$seats" ] || exit 0
  fi
  taken=''
  for s in $seats; do
    if msg=$(refresh_lock "$s"); then taken="$taken $s"; else
      for x in $taken; do rm -rf "$spool/refresh/$x.lock"; done
      die "refresh: $msg; nothing started"
    fi
  done
  rc=0
  for s in $seats; do
    ss=$(session_of "$s" "$(seat_pane "$s" || true)")
    ledger_add refresh-requested "$s" "$(printf '%s' "$ss" | cut -f1)" "$(printf '%s' "$ss" | cut -f2)" "the user, \"$words\", $src"
    if err=$(tmux run-shell -b "$(run_env)sh $(q "$self") _refresh $(q "$s") $(q "$words") $(q "$src") >> $(q "$spool/log") 2>&1" 2>&1); then
      say "refresh of $s started; the lead gets a report when it ends"
    else
      rm -rf "$spool/refresh/$s.lock"
      err=$(printf '%s' "${err:-no message}" | tr '\n' ' ') # tmux's own error (RF-Q23)
      ledger_add refresh-failed "$s" "$(printf '%s' "$ss" | cut -f1)" "$(printf '%s' "$ss" | cut -f2)" "start: $err"
      say_err "refresh of $s not started: tmux run-shell: $err"
      rc=1
    fi
  done
  [ -z "$ledger_err" ] || echo "$ledger_err" >&2
  exit $rc
  ;;
_refresh)
  refresh_run "$2" "$3" "$4"
  ;;
retire)
  { [ $# -eq 2 ] || { [ $# -eq 4 ] && [ "$3" = --no-checkout ]; }; } ||
    { echo "usage: $0 retire <name> [--no-checkout \"<reason>\"]" >&2; exit 2; }
  window_exists "$2" || record "$2" > /dev/null || die "no window or record $2"
  if [ $# -eq 4 ]; then
    [ -n "$(printf '%s' "$4" | tr -d ' \t\n')" ] || die "retire: --no-checkout needs a reason"
    mkdir -p "$spool" && log "retired $2 without a check-out: $4"
  else
    # Present, unreadable or empty: each said as such; only no file at all suggests --no-checkout (AW-Q91).
    found='' bad=''
    for f in "$checkouts"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$2".md; do
      [ -e "$f" ] || continue
      if ! [ -r "$f" ] || ! c=$(cat "$f" 2> /dev/null); then bad="cannot read $f"
      elif [ -z "$(printf '%s' "$c" | tr -d ' \t\n')" ]; then bad="$f is empty"
      else found=$f
      fi
    done
    [ -n "$found" ] || [ -z "$bad" ] || die "retire: $2's check-out: $bad; fix it, then retire again"
    [ -n "$found" ] || die "retire: no check-out for $2: the seat writes $checkouts/$(date +%F)-$2.md following $(cd "$(dirname "$(readlink -f "$self")")" && pwd)/checkout.md and commits it, then retire again; or retire $2 --no-checkout \"<reason>\""
  fi
  if window_exists "$2"; then tmux kill-window -t "$2"; fi
  if [ -f "$agents" ]; then
    registry_lock || die "retire: cannot lock $agents.lock; $2's window is closed, its record kept"
    awk -F '\t' -v n="$2" '$1 != n' "$agents" > "$agents.new" && mv "$agents.new" "$agents" ||
      { rm -rf "$agents.lock"; die "retire: cannot rewrite $agents"; }
    rm -rf "$agents.lock"
  fi
  ;;
revive)
  [ $# -eq 2 ] || { echo "usage: $0 revive <name>|--all" >&2; exit 2; }
  publish_qids
  ensure_lead
  if [ "$2" = --all ]; then
    rc=0
    if [ -f "$agents" ]; then
      while IFS="$tab" read -r n _; do revive_one "$n" || rc=1; done < "$agents"
    fi
    # The team board, back in window 0 unless open (TB-Q29), and the phone
    # bot's pane below it (CS-Q117); a failure is printed, the seats' exit
    # status kept.
    board=$(dirname "$(realpath "$self")")/board.mjs
    node "$board" open || say_err "revive: the board or the phone bot's pane was not set up (above): node $board open failed"
    exit $rc
  fi
  revive_one "$2"
  ;;
selftest)
  selftest
  ;;
doctor)
  doctor
  ;;
*) usage ;;
esac
