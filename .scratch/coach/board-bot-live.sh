#!/bin/sh
# Live check of board.mjs open joining the phone bot's pane (CS-Q117): a
# throwaway tmux server (-L boardbot), a lead pane (@role=lead), a bot window
# (@role=phone-bot, a sleep standing in for scripts/phone-bot), then the real
# board.mjs open, twice, and team.sh revive --all after the board is closed.
# Usage: board-bot-live.sh <board.mjs> <team.sh>
set -u
T="tmux -L boardbot"
d=$(cd "$(dirname "$0")" && pwd)/board-bot-live
rm -rf "$d"; mkdir -p "$d"; : > "$d/agents"
$T kill-server 2> /dev/null
$T new-session -d -s team -n lead -x 200 -y 50 "sleep 600"
$T set -p -t team:lead @role lead
$T new-window -d -t team: -n phone-bot "sleep 600"
$T set -p -t team:phone-bot @role phone-bot
layout() { $T list-panes -s -t team -F '   #{window_index}:#{window_name} #{@role} #{pane_left},#{pane_top} #{pane_width}x#{pane_height}'; }
export TEAM_TMUX=boardbot TEAM_AGENTS="$d/agents" TEAM_LEDGER="$d/ledger"
echo "-- open:"; node "$1" open; echo "   exit $?"; sleep 3; layout
echo "-- open again:"; node "$1" open; echo "   exit $?"; layout
echo "-- board closed, the bot back in a window of its own, then revive --all:"
$T break-pane -d -s "$($T list-panes -s -t team -F '#{@role} #{pane_id}' | awk '$1 == "phone-bot" { print $2 }')" -n phone-bot
$T kill-window -t team:board
sh "$2" revive --all 2>&1 | sed 's/^/   /'; sleep 3; layout
echo "-- no pane with @role=phone-bot:"
bot=$($T list-panes -s -t team -F '#{@role} #{pane_id}' | awk '$1 == "phone-bot" { print $2 }')
$T break-pane -d -s "$bot" -n phone-bot
$T kill-window -t team:board
$T set -pu -t "$bot" @role
node "$1" open; echo "   exit $?"
$T kill-server
rm -rf "$d"
