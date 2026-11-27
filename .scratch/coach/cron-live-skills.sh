#!/bin/sh
# Live check of the daily skills-check prompt (CS-Q112; named apart from doc-freshness's cron-live.sh): the crontab line's
# command, run with cron's bare environment (env -i), against a throwaway tmux
# server (-L skillscron) whose window "lead" runs a real pi with no tools and
# @role lead. In the wiki's crontab the command runs on the team's own server.
# Usage: cron-live.sh <team.sh>
set -u
d=$(cd "$(dirname "$0")" && pwd)/cron-live
rm -rf "$d"; mkdir -p "$d/spool"
T="tmux -L skillscron"
$T kill-server 2> /dev/null
$T new-session -d -s c -n lead -x 160 -y 40 "pi --no-session -nt -ne"
$T set -p -t c:lead @role lead
sleep 10
text='Cron (daily): check the global skills: npx skills check -g; ask the operator before updating any (rules.md, Team mechanics). Reply with only OK.'
env -i HOME="$HOME" TEAM_TMUX=skillscron TEAM_SPOOL="$d/spool" \
  /usr/bin/env PATH=/usr/local/bin:/usr/bin:/bin sh "$1" send lead "$text" >> "$d/cron.log" 2>&1
echo "send exit $?"
sleep 30
echo "-- cron.log:"; cat "$d/cron.log"
echo "-- lead pane:"; $T capture-pane -p -J -t c:lead | grep -v '^\s*$' | grep -E 'skills check|OK' | head -3
$T kill-server
rm -rf "$d"
