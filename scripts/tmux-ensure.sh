#!/usr/bin/env bash
# tmux-ensure [-L SOCKET] -- make sure a tmux server is running, and that it lives in its
# own systemd --user scope rather than in whatever started it.
#
# A server started from a terminal belongs to that terminal's GNOME app scope, which a
# desktop logout stops, taking every pane with it (2026-10-14 11:01). Started here it
# survives logout, given linger (loginctl enable-linger), and only a reboot ends it.
#
# The scope name is unique per start: processes nohup'd from a pane stay in the old
# scope after the server dies, keeping it active, so a fixed name would fail next time.
# The environment is clean so panes do not inherit the caller's (e.g. a Claude Code
# session's CLAUDECODE); panes are login shells and rebuild PATH etc. themselves.
#
# Without systemd (macOS, containers) there is no scope to put the server in, so this
# does nothing and leaves `ta` to start tmux the ordinary way.
set -euo pipefail
command -v systemd-run >/dev/null 2>&1 || exit 0
sock=()
if [ "${1:-}" = -L ]; then sock=(-L "$2"); shift 2; fi

tmux "${sock[@]}" has-session 2>/dev/null && exit 0

unit="tmux-server-$(date +%Y%m%d-%H%M%S)-$$"
env -i HOME="$HOME" USER="$USER" LOGNAME="${LOGNAME:-$USER}" SHELL="${SHELL:-/bin/bash}" \
    LANG="${LANG:-C.UTF-8}" PATH=/usr/local/bin:/usr/bin:/bin TERM="${TERM:-xterm-256color}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}" \
    ${SSH_AUTH_SOCK:+SSH_AUTH_SOCK="$SSH_AUTH_SOCK"} \
    systemd-run --user --scope --quiet --unit="$unit" --description="tmux server" \
    tmux "${sock[@]}" new-session -d -s main -c "$HOME"

# systemd-run returning is not proof: read where the server actually is.
pid="$(tmux "${sock[@]}" display -p '#{pid}')"
if ! grep -q "/$unit.scope\$" "/proc/$pid/cgroup"; then
    echo "tmux-ensure: server $pid is NOT in $unit.scope: $(cat "/proc/$pid/cgroup")" >&2
    echo "tmux-ensure: it will not survive a desktop logout" >&2
    exit 1
fi
if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != yes ]; then
    echo "tmux-ensure: warning: linger is off, so logging out still stops the server" >&2
fi
