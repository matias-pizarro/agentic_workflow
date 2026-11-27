#!/bin/sh
# Live check of the weekly drift-read prompt (CS-Q108 (d)): the crontab line's
# command, run with cron's bare environment (env -i), against a throwaway tmux
# server (-L crontest) whose window "librarian" runs a real pi with no tools.
# TEAM_TMUX and TEAM_SPOOL point the command there; in the wiki's crontab the
# command runs without them, on the team's own server.
# Usage: cron-live.sh <team.sh>
set -u
d=$(cd "$(dirname "$0")" && pwd)/cron-live
rm -rf "$d"; mkdir -p "$d/spool"
T="tmux -L crontest"
$T kill-server 2> /dev/null
$T new-session -d -s c -n librarian -x 160 -y 40 "pi --no-session -nt -ne"
sleep 10
text='Lead (cron, weekly): the drift read (rules.md rule 16): read the docs against CONSTANTS, the ADRs, COMPONENTS.md and the live inventory; send each stale line to its owner through the lead. Reply with only OK.'
env -i HOME="$HOME" TEAM_TMUX=crontest TEAM_SPOOL="$d/spool" \
  /usr/bin/env PATH=/usr/local/bin:/usr/bin:/bin sh "$1" send librarian "$text" >> "$d/cron.log" 2>&1
echo "send exit $?"
sleep 30
echo "-- cron.log:"; cat "$d/cron.log"
echo "-- librarian pane:"; $T capture-pane -p -J -t c:librarian | grep -v '^\s*$' | grep -E 'drift read|OK' | head -4
$T kill-server
