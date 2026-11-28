#!/bin/sh
# Live check (CS-Q121): a real pi in a seat-like pane of a throwaway tmux
# server (-L subq) starts a background subagent with pi-subagents. The pi
# and its subagent load their extensions from a throwaway agent dir
# (PI_CODING_AGENT_DIR, inherited by the subagent): the installed ones but
# for the four pane-writing ones, taken from <dir>, plus a debug extension
# logging what each session sees. Every other entry of ~/.pi/agent is linked.
# Afterwards the ledger must hold only the main session's lines, and the
# pane's @session-id be the main's.
# Usage: subagent-live.sh <dir of ledger.ts refresh.ts beep.ts open-questions.ts>
set -u
ext=$1
here=$(cd "$(dirname "$0")" && pwd)
d=$here/subagent-live
rm -rf "$d"; mkdir -p "$d/sessions" "$d/agent/extensions"; : > "$d/ledger"
for e in "$HOME"/.pi/agent/* "$HOME"/.pi/agent/.gitignore; do
  case ${e##*/} in extensions | sessions) ;; *) ln -s "$e" "$d/agent/${e##*/}" ;; esac
done
for f in "$HOME"/.pi/agent/extensions/*.ts; do cp "$f" "$d/agent/extensions/"; done
for f in ledger refresh beep open-questions; do cp "$ext/$f.ts" "$d/agent/extensions/"; done
cp "$here/debug-ext/debug.ts" "$d/agent/extensions/"
T="tmux -L subq"
$T kill-server 2> /dev/null
$T new-session -d -s q -n seatx -x 200 -y 50 \
  "env PI_CODING_AGENT_DIR=$d/agent PI_CODING_AGENT_SESSION_DIR=$d/sessions DEBUG_LOG=$d/debug.log pi"
$T set -g @team-ledger "$d/ledger"
sleep 15
$T send-keys -t q:seatx -l 'Call the subagent tool once with agent "delegate", async true, and task "Reply with only the word OK." Then wait for it to finish, and reply with exactly this line: STATUS seat=seatx state=idle open=0'
$T send-keys -t q:seatx Enter
sleep 100
echo "-- ledger:"; cut -f2-5 "$d/ledger"
echo "-- the pane's @session-id: $($T show -pv -t q:seatx @session-id 2> /dev/null)"
echo "-- the pane's @state: $($T show -wv -t q:seatx @state 2> /dev/null)"
echo "-- sessions seen (debug): event, subagent child env, parentSession set, file:"
sed -n 's/.*"ev":"\([a-z_]*\)","file":"\([^"]*\)".*"child":\([^}]*\)}.*/\1 child=\3 \2/p' "$d/debug.log" 2> /dev/null | sed "s|$d/sessions/||" | sort | uniq -c
echo "-- pane:"; $T capture-pane -p -J -t q:seatx | grep -v '^\s*$' | tail -4
$T kill-server
rm -rf "$d/agent"
