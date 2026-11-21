#!/bin/sh
# Live check for the board's working row: on a throwaway tmux server
# (tmux -L, named after this run's temp dir), a seat window carrying the previous turn's
# @state=waiting-for-PM @for=PM and @working=1, as phone-comms did on
# 21 Nov 16:50; board.mjs seats drawn in another window and its pane read.
# Usage: live.sh <board.mjs>   Exit 0 when the row shows working, no waiting-for.
set -u
board=$1
dir=$(mktemp -d)
S=board-working-live-${dir##*/}
t() { tmux -L "$S" "$@"; }
trap 't kill-server 2>/dev/null; rm -rf "$dir" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$S"' EXIT
trap 'exit 130' INT TERM HUP
printf 'phone-comms\tx\tx\tsid1\nidle-seat\tx\tx\tsid2\n' > "$dir/agents"
: > "$dir/ledger"
t new-session -d -s team -n phone-comms -x 160 -y 20 'sleep 600'
t set -w -t team:phone-comms @state waiting-for-PM
t set -w -t team:phone-comms @for PM
t set -w -t team:phone-comms @open 1
t set -w -t team:phone-comms @worst high
t set -w -t team:phone-comms @ctx 40
t set -w -t team:phone-comms @working 1
t new-window -d -t team -n idle-seat 'sleep 600'
t set -w -t team:idle-seat @state waiting-for-PM
t set -w -t team:idle-seat @for PM
t set -w -t team:idle-seat @open 1
t set -w -t team:idle-seat @worst high
t set -w -t team:idle-seat @ctx 10
t new-window -d -t team -n board "TEAM_TMUX=$S TEAM_AGENTS=$dir/agents TEAM_LEDGER=$dir/ledger node $board seats"
sleep 3
out=$(t capture-pane -p -t team:board)
printf '%s\n' "$out"
row=$(printf '%s\n' "$out" | grep '^phone-comms')
idle=$(printf '%s\n' "$out" | grep '^idle-seat')
ok=0
case $row in *" working "*) ;; *) echo "FAIL: phone-comms (@working 1) does not show state working"; ok=1 ;; esac
case $row in *PM*) echo "FAIL: phone-comms (@working 1) still shows waiting-for PM"; ok=1 ;; esac
case $idle in *waiting-for-PM*PM*) ;; *) echo "FAIL: idle-seat (no @working) lost its waiting-for-PM / PM"; ok=1 ;; esac
[ $ok = 0 ] && echo "PASS: working seat shows working, no waiting-for; idle seat unchanged"
exit $ok
