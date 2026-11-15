#!/bin/sh
# Team script of the chief of staff (the lead). One tmux window per agent; the
# window name is the agent's identity. Mechanics follow
# src/chief-of-staff-communication.md (11 Nov 2026).
#   team.sh spawn <name> <cwd> <task file>   start an interactive pi agent with its own session id;
#                                            the task file's first line is the ceremony the user chose:
#                                            Ceremony: <checklist|script|full|none> (the user, "<words>", <date> hh:mm)
#                                            (none for research, retros and other no-code tasks)
#   team.sh send <name> "<text>"             queue one message for an agent's pane
#   team.sh go <name> "<words>" "<instr>"    queue "Lead: the user's go, lead pane, <time> ('<words>'): <instr>"
#   team.sh report "<text>"                  agent -> lead: queue one message for the lead's pane
#   team.sh status                           last STATUS line of every agent, [busy] flag; queued and failed messages
#   team.sh retire <name>                    close a finished agent's window, drop its record
#   team.sh revive <name>|--all              after a tmux restart, reopen recorded agents in their sessions
#   team.sh queue                            undelivered and failed messages
#   team.sh selftest                         test delivery, go, spawn and revive on tmux -L teamtest
#   team.sh doctor                           check the host dependencies in tools/expect; print one fix block
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
  tmux capture-pane -p -t "$1" 2>/dev/null | LC_ALL=C awk -v r="$rule" '
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

# Append text to the target's queue, then make sure a deliverer runs.
enqueue() { # target text
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
  echo "queued for $1: $f"
  log "queued $f"
  p=$(resolve "$1")
  if [ -n "$p" ] && busy "$p"; then
    echo "${1#to-} is busy: once typed, pi holds the message as steering until the agent's current step ends; while its input box holds text it waits here (team.sh status: QUEUED)"
  fi
  # Detach from the caller's session, so the deliverer outlives the agent's
  # shell command (pi kills the process group of its bash calls).
  if command -v daemon > /dev/null; then
    daemon -o "$spool/log" sh "$self" _deliver "$1"
  else
    nohup sh "$self" _deliver "$1" < /dev/null > /dev/null 2>&1 &
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

# The first message of an agent: the protocol, then its task file. Prints the
# path of a temporary file holding it.
compose_prompt() { # name task-file
  full=$(mktemp "${TMPDIR:-/tmp}/cos-task-$1.XXXXXX")
  cat > "$full" <<HDR
You are the agent \`$1\` on a team led by a chief of staff (the lead). Protocol:
- End EVERY turn with exactly one line:
  STATUS seat=$1 state=<working|waiting-for-PM|waiting-for-seat|ready-for-lead|blocked|idle|done> [ask="<one sentence>"] [pointer=<path or commit>]
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
open_window() { # name cwd session-id [prompt file]
  inner="unset TEAM_ROLE; exec $(q "$pi_cmd") --session-id $(q "$3")"
  [ $# -lt 4 ] || inner="$inner \"\$(cat $(q "$4"))\""
  tmux new-window -d -n "$1" -c "$2" "bash -ic $(q "$inner")"
}

# A task file must exist and hold more than blank space.
task_ok() { [ -f "$1" ] && grep -q '[^[:space:]]' "$1"; }

# The task file's first line names the ceremony the user chose, with their
# words and time (wiki decision-ceremony-sizing.md).
ceremony_ok() {
  first=$(head -n 1 "$1") || return 1
  grep -Eq '^Ceremony: (checklist|script|full|none) .*"[^"]+".*[0-9][0-9]:[0-9][0-9]' <<EOF
$first
EOF
}

revive_one() { # name
  rec=$(record "$1") || { echo "$1 is not recorded in $agents" >&2; return 1; }
  cwd=$(printf '%s\n' "$rec" | cut -f2)
  task=$(printf '%s\n' "$rec" | cut -f3)
  id=$(printf '%s\n' "$rec" | cut -f4)
  if window_exists "$1"; then
    echo "$1: window exists, left alone"
  elif session_exists "$id"; then
    open_window "$1" "$cwd" "$id"
    echo "revived $1 in session $id"
  elif task_ok "$task"; then
    # pi saves a session only once it has a reply; start over from the task.
    open_window "$1" "$cwd" "$id" "$(compose_prompt "$1" "$task")"
    echo "revived $1: no saved session $id, restarted from $task"
  else
    echo "$1: no saved session $id and task file $task is missing or empty; not revived" >&2
    return 1
  fi
}

# After a tmux restart no pane has @role=lead; revive is run by the lead, so
# its own pane gets it, unless that pane is an agent's.
ensure_lead() {
  [ -z "$(lead_pane 2>/dev/null)" ] || return 0
  if [ -z "${TMUX_PANE:-}" ]; then
    echo "no pane has @role=lead; run tmux set -p @role lead in the lead pane" >&2
    return 0
  fi
  win=$(tmux display -p -t "$TMUX_PANE" '#{window_name}')
  if record "$win" > /dev/null; then
    echo "no pane has @role=lead, and $TMUX_PANE is agent $win's; run tmux set -p @role lead in the lead pane" >&2
    return 0
  fi
  tmux set -p -t "$TMUX_PANE" @role lead
  echo "set @role=lead on $TMUX_PANE"
}

# doctor: check each host dependency in tools/expect (TEAM_EXPECT overrides),
# one per line: "<kind> <target> <expected> | <the host-side fix>", # for
# comments. Kinds: sysctl <name> <value>; nonempty <file>; sshcontrolpath
# <alias> %n (ssh -G <alias> prints a ControlPath holding the alias, so two
# aliases of one host never share a socket); jail <name>, the jail's name for
# the fix block, checking nothing. Prints each failure, then one block for the
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
      if [ -s "$target" ]; then ok=1; elif [ -e "$target" ]; then got=empty; else got='missing or unreadable'; fi ;;
    sshcontrolpath)
      got=$(ssh -G "$target" 2>&1 | awk '$1 == "controlpath" { print $2 }') || got='ssh -G failed'
      case $got in *"$target"*) ok=1 ;; esac ;;
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
  tmux kill-server 2> /dev/null
  rm -rf "$st_dir"
}

selftest() {
  [ -z "${TEAM_TMUX:-}" ] || die "selftest: TEAM_TMUX is set"
  TEAM_TMUX=teamtest
  ! tmux has-session 2> /dev/null || die "selftest: a tmux -L teamtest server is running (tmux -L teamtest kill-server)"
  st_dir=$(mktemp -d "${TMPDIR:-/tmp}/teamtest.XXXXXX")
  st_fails=0
  TEAM_SPOOL=$st_dir/spool TEAM_AGENTS=$st_dir/agents TEAM_POLL=1
  PI_CODING_AGENT_SESSION_DIR=$st_dir/sessions
  export TEAM_TMUX TEAM_SPOOL TEAM_AGENTS TEAM_POLL PI_CODING_AGENT_SESSION_DIR
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
  check "send refuses a text claiming a user's go" refused send agent "Lead: the user's go, lead pane, now ('yes'): x"
  check "go refuses empty words" refused go agent "" "x"
  check "go refuses '...'" refused go agent "..." "x"
  check "go refuses '…'" refused go agent " … " "x"
  half="selftest: a half-typed line of the user; reply with only OK"
  tmux send-keys -t "$lp" -l -- "$half"
  check "an input box holding text counts as not empty" waitfor 5 holds_text "$lp"
  sh "$self" report "selftest report one: reply with only OK" > /dev/null
  sh "$self" report "selftest report two: reply with only OK" > /dev/null
  sh "$self" go agent "go ahead" "selftest go: reply with only OK" > /dev/null
  check "go is delivered into an empty box, quoting the user's words" waitfor 30 has "$ap" "the user's go, lead pane,"
  check "go quotes the words" has "$ap" "('go ahead'): selftest go"
  sleep 4
  check "reports wait while the lead's box holds text" queued lead 2
  check "status lists them as QUEUED, with their age" status_shows_queued
  check "... and are not typed" lacks "$lp" "selftest report one"
  tmux send-keys -t "$lp" -l -- "$cr" # the user submits the line
  check "the reports are delivered once the user's line is submitted" waitfor 120 queued lead 0
  check "... in order, after the user's line" waitfor 60 in_order "$lp" "$half" "selftest report one" "selftest report two"
  waitfor 60 input_empty "$ap" || true
  tmux send-keys -t "$ap" -l -- "selftest: the user types in the agent pane"
  TEAM_WAIT=3 sh "$self" send agent "selftest: a message that times out" > /dev/null
  check "a message waiting past TEAM_WAIT moves to failed/" waitfor 20 failed_any to-agent
  check "status prints the failed message" status_shows_failed

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
  TMUX_PANE=$lp sh "$self" revive --all > /dev/null
  check "revive re-sets @role=lead on the lead pane" is_lead "$lp"
  check "revive reopens a saved session, with no prompt" waitfor 10 has st:a1 "stub-pi TEAM_ROLE=unset --session-id $id1 prompt=no"
  check "revive restarts an agent with no saved session from its task file" waitfor 10 has st:a2 "--session-id $id2 prompt=yes"
  check "revive leaves a running agent alone" revive_leaves_alone
  sh "$self" retire a1 > /dev/null
  check "retire closes the window and drops the record" gone a1
  check "... and leaves the others" recorded_as a2 "$t" "$t/task"
  check "revive refuses an unrecorded name" refused revive a1

  if [ "$st_fails" -eq 0 ]; then echo "selftest passed"; else echo "selftest: $st_fails failed"; return 1; fi
}

usage() { awk 'NR > 1 && /^#/ { print; next } NR > 1 { exit }' "$self" >&2; exit 2; }

case ${1:-} in
spawn)
  [ $# -eq 4 ] || { echo "usage: $0 spawn <name> <cwd> <task file>" >&2; exit 2; }
  name=$2
  case $name in '' | *"$tab"* | *[!A-Za-z0-9._-]*) die "spawn: bad name '$name'" ;; esac
  cwd=$(cd "$3" && pwd) || exit 1
  task_ok "$4" || die "spawn: task file $4 is missing or empty"
  ceremony_ok "$4" ||
    die "spawn: task file $4 has no Ceremony line first: Ceremony: <checklist|script|full|none> (the user, \"<words>\", <date> hh:mm)"
  task=$(cd "$(dirname "$4")" && pwd)/$(basename "$4")
  ! window_exists "$name" || die "window $name exists"
  ! record "$name" > /dev/null || die "$name is recorded in $agents: team.sh revive or retire it"
  id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  open_window "$name" "$cwd" "$id" "$(compose_prompt "$name" "$task")"
  printf '%s\t%s\t%s\t%s\n' "$name" "$cwd" "$task" "$id" >> "$agents"
  echo "spawned $name (session $id)"
  ;;
send)
  [ $# -eq 3 ] || { echo "usage: $0 send <name> <text>" >&2; exit 2; }
  if printf '%s' "$3" | grep -qiE "user('|’)s go"; then
    die "send: the text claims a user's go; use team.sh go <name> \"<the user's exact words>\" \"<instruction>\""
  fi
  enqueue "to-$2" "$3"
  ;;
go)
  [ $# -eq 4 ] || { echo "usage: $0 go <name> \"<the user's exact words>\" \"<instruction>\"" >&2; exit 2; }
  [ -n "$(printf '%s' "$3" | sed 's/…//g' | tr -d ' \t\n.')" ] ||
    die "go: the user's words are empty or '...'; quote them exactly"
  [ -n "$(printf '%s' "$4" | tr -d ' \t\n')" ] || die "go: empty instruction"
  enqueue "to-$2" "Lead: the user's go, lead pane, $(date '+%e %b %H:%M %Z' | sed 's/^ //') ('$3'): $4"
  ;;
report)
  [ $# -eq 2 ] || { echo "usage: $0 report <text>" >&2; exit 2; }
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
  tmux list-windows -F '#{window_index} #{window_name}' | while read -r idx name; do
    [ "$idx" = "$leadwin" ] && continue
    pane=$(tmux capture-pane -p -J -S -300 -t "$idx")
    line=$(printf '%s\n' "$pane" | grep -o 'STATUS seat=.*' | tail -1)
    flag=''
    busy "$idx" && flag='[busy] '
    printf '%-16s %s%s\n' "$name" "$flag" "${line:-(no STATUS line)}"
  done
  for f in "$spool"/*/failed/*; do
    [ -f "$f" ] && printf 'FAILED %s: %s\n' "${f#"$spool"/}" "$(head -1 "$f" | cut -c1-100)"
  done
  now=$(date +%s)
  for f in "$spool"/*/q/*; do
    [ -f "$f" ] || continue
    target=${f#"$spool"/}
    age=$(mtime "$f") && age="$(((now - age) / 60))m" || age='age unreadable'
    printf 'QUEUED %s %s: %s\n' "${target%%/*}" "$age" "$(head -1 "$f" | cut -c1-80)"
  done
  true
  ;;
retire)
  [ $# -eq 2 ] || { echo "usage: $0 retire <name>" >&2; exit 2; }
  window_exists "$2" || record "$2" > /dev/null || die "no window or record $2"
  if window_exists "$2"; then tmux kill-window -t "$2"; fi
  if [ -f "$agents" ]; then
    awk -F '\t' -v n="$2" '$1 != n' "$agents" > "$agents.new" && mv "$agents.new" "$agents"
  fi
  ;;
revive)
  [ $# -eq 2 ] || { echo "usage: $0 revive <name>|--all" >&2; exit 2; }
  ensure_lead
  if [ "$2" = --all ]; then
    rc=0
    if [ -f "$agents" ]; then
      while IFS="$tab" read -r n _; do revive_one "$n" || rc=1; done < "$agents"
    fi
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
