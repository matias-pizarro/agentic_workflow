#!/bin/sh
# Live check (CO-Q38): team.sh spawn, run with PI_SUBAGENT_CHILD=1 in its own
# environment and in the tmux server's, starts the seat's command without it.
# A stub stands in for pi and writes the variable it sees.
# Usage: spawn-env-live.sh <team.sh>
set -u
d=$(cd "$(dirname "$0")" && pwd)/spawn-env-live
rm -rf "$d"; mkdir -p "$d/spool" "$d/sessions"; : > "$d/agents"; : > "$d/task"
printf '#!/bin/sh\necho "PI_SUBAGENT_CHILD=${PI_SUBAGENT_CHILD-unset}" > %s/seen\nsleep 30\n' "$d" > "$d/stub-pi"
chmod +x "$d/stub-pi"
T="tmux -L spawnenv"
$T kill-server 2> /dev/null
$T new-session -d -s s -n lead "sleep 60"
$T set -p -t s:lead @role lead
$T set-environment -g PI_SUBAGENT_CHILD 1
printf 'Ceremony: none (the operator, "x", 28 Nov 2026 14:24)\n' > "$d/task"
env PI_SUBAGENT_CHILD=1 TEAM_TMUX=spawnenv TEAM_PI="$d/stub-pi" TEAM_AGENTS="$d/agents" TEAM_SPOOL="$d/spool" \
  PI_CODING_AGENT_SESSION_DIR="$d/sessions" TEAM_ROLE=lead sh "$1" spawn seatq "$d" "$d/task" > /dev/null 2>&1
echo "spawn exit $?"
sleep 3
cat "$d/seen" 2> /dev/null || echo "the stub never ran"
$T kill-server
rm -rf "$d"
