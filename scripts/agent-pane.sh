#!/usr/bin/env bash
#
# agent-pane -- hand context to a coding agent (Claude Code and friends)
# running in another tmux pane.
#
#   agent-pane open              create the agent pane if there is not one yet
#   agent-pane focus             open it if needed, then switch to it
#   agent-pane mark [-t PANE]    remember PANE (default: the current one)
#   agent-pane forget            drop the remembered pane
#   agent-pane id                print the agent pane id, or fail
#   agent-pane send [OPT]... [TEXT...|-]
#                                paste TEXT (or stdin) into the agent pane
#   agent-pane output [OPT]...   paste a pane's recent output into it
#
# send/output options:
#   -e, --enter        press Enter afterwards, i.e. actually submit
#   -f, --focus        switch to the agent pane after pasting
#   -F, --fenced       wrap the text in a ``` code fence
#   -L, --lang LANG    language for that fence
#   -H, --header TEXT  a line placed above the fence
#   -t, --target PANE  the pane to read from (output) -- not the agent pane
#   -n, --lines N      how many lines to capture (output, default 200)
#
# Text is pasted, not typed: it goes in as a bracketed paste through a tmux
# buffer, so newlines stay newlines instead of submitting a half-written
# prompt line by line. Nothing is sent until you ask for it with --enter,
# which leaves you free to add the actual question first.
#
# Which pane is the agent? In order: $VIMIDE_AGENT_PANE, the @agent_pane tmux
# option (window first, then session -- set by `open` and `mark`), then any
# pane in this session whose command looks like a known agent. The pane you
# are calling from is never chosen, so vim cannot end up talking to itself.

set -euo pipefail

BUF=vimide-agent            # our own tmux buffer name, reused every time
DEFAULT_LINES=200

die()  { printf 'agent-pane: %s\n' "$1" >&2; exit 1; }
usage() { sed -n '3,32p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,2\} \{0,1\}//'; exit 0; }

# --help before the tmux check: reading the usage from outside tmux is fair.
case "${1:-}" in -h|--help|help|'') usage ;; esac

[ -n "${TMUX:-}" ] || die "not inside tmux"
command -v tmux >/dev/null 2>&1 || die "tmux not found on PATH"

# A tmux user option, or a default. -q keeps tmux quiet about unset options;
# an empty scope means session scope, which show-options spells as no flag.
opt() {
    local v
    if [ -n "$1" ]; then
        v="$(tmux show-options -qv "$1" "$2" 2>/dev/null || true)"
    else
        v="$(tmux show-options -qv "$2" 2>/dev/null || true)"
    fi
    printf '%s' "${v:-$3}"
}

# What to run in a new agent pane, and how to split for it. Both are tmux
# options so they can be set in tmux.conf, where run-shell can actually see
# them -- run-shell inherits the tmux *server* environment, not your shell's.
agent_cmd()   { printf '%s' "${VIMIDE_AGENT_CMD:-$(opt -g @agent_cmd claude)}"; }
agent_split() { printf '%s' "${VIMIDE_AGENT_SPLIT:-$(opt -g @agent_split auto)}"; }

# Panes whose command matches this are treated as an agent when nothing has
# been marked. Deliberately conservative: `node` and `python` are not here,
# because guessing wrong means pasting your code into an unrelated program.
AGENT_RE="${VIMIDE_AGENT_RE:-$(opt -g @agent_re '^(claude|aider|codex|opencode|goose|crush|amp|cursor-agent)$')}"

# "40% of the window", spelled the way this tmux understands. `-l 40%` is the
# modern form; tmux 3.0a (Ubuntu 20.04) only has the deprecated `-p 40`.
pct() {
    local v
    v="$(tmux -V | sed 's/[^0-9.]//g')"
    if awk -v v="$v" 'BEGIN { split(v, a, "."); exit !(a[1] > 3 || (a[1] == 3 && a[2] >= 1)) }'; then
        printf -- '-l %s%%' "$1"
    else
        printf -- '-p %s' "$1"
    fi
}

pane_alive() {
    [ -n "${1:-}" ] || return 1
    tmux list-panes -a -F '#{pane_id}' | grep -qxF "$1"
}

# The pane we were invoked from: tmux exports TMUX_PANE into every pane, and
# key bindings pass #{pane_id} explicitly since run-shell has no pane of its own.
self_pane() { printf '%s' "${SELF_PANE:-${TMUX_PANE:-}}"; }

# Recorded against the window we were called from -- run-shell has no pane of
# its own, so without -t tmux would guess from the active client instead.
remember() {
    local self; self="$(self_pane)"
    if [ -n "$self" ]; then
        tmux set-option -w -t "$self" @agent_pane "$1"
        tmux set-option    -t "$self" @agent_pane "$1"
    else
        tmux set-option -w @agent_pane "$1"
        tmux set-option    @agent_pane "$1"
    fi
}

# Print the agent pane id, or nothing.
find_pane() {
    local id self
    self="$(self_pane)"

    for id in "${VIMIDE_AGENT_PANE:-}" \
              "$(opt -w @agent_pane '')" \
              "$(opt '' @agent_pane '')"
    do
        if pane_alive "$id" && [ "$id" != "$self" ]; then
            printf '%s' "$id"
            return 0
        fi
    done

    # Nothing marked: look for something that is obviously an agent, current
    # window first so a second agent elsewhere does not win.
    local scope
    for scope in '' '-s'; do
        while read -r id cmd; do
            [ "$id" = "$self" ] && continue
            if printf '%s' "$cmd" | grep -qE "$AGENT_RE"; then
                printf '%s' "$id"
                return 0
            fi
        done < <(tmux list-panes $scope -F '#{pane_id} #{pane_current_command}')
    done

    return 1
}

open_pane() {
    local id cmd split w
    if id="$(find_pane)"; then
        printf '%s' "$id"
        return 0
    fi

    cmd="$(agent_cmd)"
    split="$(agent_split)"
    if [ "$split" = auto ]; then
        # Side by side only when the result is still wide enough to read;
        # below that a bottom split beats two cramped columns.
        w="$(tmux display-message -p '#{window_width}')"
        if [ "${w:-0}" -ge 180 ]; then split="-h $(pct 40)"; else split="-v $(pct 40)"; fi
    fi

    # -d: create it in the background, so `open` does not steal focus.
    # shellcheck disable=SC2086
    id="$(tmux split-window -d -P -F '#{pane_id}' $split -c '#{pane_current_path}' "$cmd")"
    remember "$id"
    printf '%s' "$id"
}

# paste <pane-id> <enter?> <focus?>   -- text on stdin
paste_to() {
    local id="$1" enter="$2" focus="$3"
    tmux load-buffer -b "$BUF" -
    tmux paste-buffer -d -p -b "$BUF" -t "$id"
    [ "$enter" = 1 ] && tmux send-keys -t "$id" Enter
    [ "$focus" = 1 ] && tmux select-pane -t "$id"
    return 0
}

# ------------------------------------------------------------------- main ---
sub="$1"; shift

enter=0 focus=0 fenced=0 lang='' header='' target='' lines="$DEFAULT_LINES"
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -e|--enter)  enter=1 ;;
        -f|--focus)  focus=1 ;;
        -F|--fenced) fenced=1 ;;
        -L|--lang)   lang="${2:-}"; shift ;;
        -H|--header) header="${2:-}"; shift ;;
        -t|--target) target="${2:-}"; shift ;;
        -n|--lines)  lines="${2:-}"; shift ;;
        -h|--help)   usage ;;
        --)          shift; args+=("$@"); break ;;
        *)           args+=("$1") ;;
    esac
    shift
done

case "$sub" in
    id)
        find_pane || die "no agent pane (start one with: agent-pane open)"
        printf '\n'
        ;;

    open)
        open_pane; printf '\n'
        ;;

    focus)
        tmux select-pane -t "$(open_pane)"
        ;;

    mark)
        id="${target:-$(self_pane)}"
        pane_alive "$id" || die "no such pane: $id"
        remember "$id"
        tmux display-message "agent pane: $id"
        ;;

    forget)
        tmux set-option -wu @agent_pane 2>/dev/null || true
        tmux set-option -su @agent_pane 2>/dev/null || true
        tmux display-message "agent pane forgotten"
        ;;

    send)
        id="$(open_pane)"
        if [ "${#args[@]}" -eq 0 ] || [ "${args[0]}" = '-' ]; then
            text="$(cat)"
        else
            text="${args[*]}"
        fi
        [ -n "$text" ] || die "nothing to send"
        {
            [ -n "$header" ] && printf '%s\n' "$header"
            if [ "$fenced" = 1 ]; then
                printf '```%s\n%s\n```\n' "$lang" "$text"
            else
                printf '%s' "$text"
            fi
        } | paste_to "$id" "$enter" "$focus"
        ;;

    output)
        id="$(open_pane)"
        src="${target:-$(self_pane)}"
        [ -n "$src" ] || die "no source pane (pass -t)"
        [ "$src" != "$id" ] || die "refusing to feed the agent pane its own output"
        # -J unwraps what the terminal folded, so a long traceback line arrives
        # in one piece. $() already eats the trailing blank lines a live prompt
        # leaves behind.
        text="$(tmux capture-pane -p -J -S "-$lines" -t "$src")"
        [ -n "${text//[[:space:]]/}" ] || die "pane $src has no output to send"
        cmd="$(tmux display-message -p -t "$src" '#{pane_current_command}')"
        printf '%s\n```console\n%s\n```\n' \
            "${header:-Last $lines lines from the $cmd pane:}" "$text" \
            | paste_to "$id" "$enter" "$focus"
        ;;

    -h|--help|help) usage ;;
    *) die "unknown command: $sub (try --help)" ;;
esac
