tmux
====

What `tmux.conf` sets up, and the `agent-pane` helper that goes with it. See
[vim.md](vim.md) for the editor side, and the [README](../README.md) for
installation.

The prefix is `C-a`, not `C-b`. `C-a C-a` sends a literal `C-a` through to the
program in the pane (readline's "start of line"). Windows and panes are
numbered from 1, because 0 is at the wrong end of the keyboard.

Keys
----

### Behind the prefix

| Key | Does |
| --- | --- |
| `r` | reload `~/.tmux.conf` |
| `k` | clear the pane *and* its scrollback |
| `C-l` | send a literal `C-l`, since the bare key is taken by pane navigation |
| `a` | open the coding-agent pane, or jump to it |
| `A` | mark the current pane as the agent |
| `P` | paste this pane's last 200 lines into the agent |

Everything else is stock: `c` new window, `%` and `"` splits, `z` zoom, `[`
copy mode, `d` detach.

### Without the prefix

| Key | Does |
| --- | --- |
| `C-h/j/k/l` | move between panes -- **and vim splits**, transparently |
| `C-\` | back to the last pane |

That is vim-tmux-navigator's own recommended snippet. It decides whether the
pane is running vim by inspecting the process state on the pane's tty rather
than by matching `#{pane_current_command}`, so it also does the right thing for
fzf and for wrapped or full-path vim invocations. The same four keys are bound
inside copy mode.

The cost is that `C-l` no longer clears the screen; `prefix C-l` sends one, and
`prefix k` clears the scrollback with it.

### Copy mode

Copy mode is vi-keyed (`setw -g mode-keys vi`).

| Key | Does |
| --- | --- |
| `v` | start the selection |
| `y`, `Enter` | copy the selection to the system clipboard and leave copy mode |
| `Y` | send the selection to the coding-agent pane as a fenced block |
| `C-h/j/k/l` | switch panes without leaving copy mode |

The mouse is on, so the wheel scrolls straight into copy mode and a drag
selects.

Clipboard
---------

`tmux.conf` picks a backend once, at config load, and both copy bindings
inherit it through `copy-command`:

```tmux
if-shell 'command -v xclip'   'set -s copy-command "xclip -selection clipboard -i"'
if-shell 'command -v wl-copy' 'set -s copy-command "wl-copy"'
if-shell 'command -v pbcopy'  'set -s copy-command "pbcopy"'
```

Later matches win, so the order is least- to most-preferred. If none are
present, yanks fall back to tmux's internal buffer. Check which one was chosen:

```sh
tmux show-options -sv copy-command
```

Two things that catch people out:

- tmux runs these through a non-interactive `sh -c`, so a **shell alias is not
  visible** here -- the backend has to be a real executable. The
  `pbcopy`/`pbpaste` aliases in `bash_aliases` do not count.
- `reattach-to-user-namespace` is **not** needed on macOS and has not been
  since 10.12 / tmux 2.6.

On Ubuntu 24.04, which is Wayland by default, that means `wl-clipboard`, with
`xclip` as the X11 fallback.

Terminal and colour
-------------------

| Setting | Why |
| --- | --- |
| `default-terminal "tmux-256color"` | advertises italics and proper sgr; `screen-256color` is the older, more limited entry |
| `terminal-features ',*:RGB'` | lets truecolor through from an outer terminal that supports it (tmux 3.2+) |
| `escape-time 10` | the default 500ms is what makes `<Esc>` feel laggy inside vim. 10ms is still ample for real escape sequences |
| `focus-events on` | pane focus is reported to the program in the pane -- see below |
| `history-limit 10000` | scrollback per pane |

**terminfo.** If the `tmux-256color` entry is missing, tmux refuses to start at
all -- a hard failure, not a degraded mode. `createLinks.sh` compiles
`res/tmux-256color.terminfo` into `~/.terminfo` (per-user, no root) only when
`infocmp` cannot already find the entry, which is the case on Ubuntu 20.04 and
some minimal images. On anything current the step reports `ok` and does
nothing. By hand, the same thing is:

```sh
infocmp -x tmux-256color > /tmp/t && tic -x /tmp/t
```

**Focus events.** `focus-events on` is necessary for the vimrc's save-on-leave
and reload-on-return, but it is not sufficient: Vim also has to ask the
terminal for focus reporting, and it does not do that for `term=tmux-256color`
on its own. The vimrc sets `t_fe`/`t_fd` by hand. See
[vim.md § Staying in sync with an agent](vim.md#staying-in-sync-with-an-agent).

**Older tmux.** On tmux 3.0a (Ubuntu 20.04), `terminal-features` and
`copy-command` both need 3.2+, so truecolor is not advertised and copy-mode
yanks land in the tmux buffer rather than the system clipboard. 22.04 ships
3.2a and is unaffected. An unknown *option* is skipped and the rest of the
config still loads; an unknown *command* aborts the rest of the file, which is
why the CI smoke test reports which settings actually survived.

Coding agent in another pane
----------------------------

The layout: vim in one pane, a coding agent (Claude Code, or anything else that
runs in a terminal) in another, both on the same working tree. The vim half is
in [vim.md § Coding agent](vim.md#coding-agent); this is everything else.

| Key | Does |
| --- | --- |
| `prefix a` | open the agent pane, or jump to it if it is already there |
| `prefix A` | mark the current pane as the agent -- one you started by hand, a second one, an agent running over ssh |
| `prefix P` | paste this pane's last 200 lines into the agent: the failing test run, the traceback, the log you are staring at |
| `Y` in copy mode | send just the selection -- the six lines that matter out of a thousand-line log |

Nothing is ever submitted for you: text is pasted into the agent's prompt and
left there, so you can add the actual question first.

### The `agent-pane` command

All of the above goes through `scripts/agent-pane.sh`, linked to
`~/bin/agent-pane`. It is useful on its own:

```sh
pytest 2>&1 | agent-pane send -F -      # hand over a test run, fenced
agent-pane send -F -L python -H 'look at this:' - < snippet.py
agent-pane output -n 500                # more scrollback than prefix P takes
agent-pane id                           # which pane is it talking to?
```

| Subcommand | Does |
| --- | --- |
| `open` | create the agent pane if there is not one yet; print its id |
| `focus` | open it if needed, then switch to it |
| `mark [-t PANE]` | remember a pane as the agent (default: the current one) |
| `forget` | drop the remembered pane |
| `id` | print the agent pane id, or fail |
| `send [OPT]... [TEXT\|-]` | paste text, or stdin, into the agent pane |
| `output [OPT]...` | paste a pane's recent output into it |

| Option | Does |
| --- | --- |
| `-e`, `--enter` | press Enter afterwards, i.e. actually submit |
| `-f`, `--focus` | switch to the agent pane after pasting |
| `-F`, `--fenced` | wrap in a fenced code block |
| `-L`, `--lang LANG` | language for that fence |
| `-H`, `--header TEXT` | a line above the fence |
| `-t`, `--target PANE` | the pane to read *from* (`output`), not the agent pane |
| `-n`, `--lines N` | how many lines to capture (`output`, default 200) |

`agent-pane --help` has the same list.

### How it finds the pane

In order: `$VIMIDE_AGENT_PANE`, the `@agent_pane` tmux option (window scope
first, then session -- set by `open` and `prefix A`), then any pane in this
session whose command matches `@agent_re`. The pane asking is never chosen, so
vim cannot end up talking to itself. If nothing is found, a pane is opened.

`@agent_re` is deliberately conservative -- `node` and `python` are not in it,
because guessing wrong means pasting your code into an unrelated program. Mark
the pane with `prefix A` instead.

### Configuration

Options, not environment variables, on purpose: `run-shell` inherits the tmux
*server* environment, which is whatever your login shell looked like when the
server started -- not what your current shell exports.

```tmux
set -g @agent_cmd   'claude'    # what to run in a new agent pane
set -g @agent_split 'auto'      # 'auto', or any split-window flags e.g. '-h -l 50%'
set -g @agent_re    '^(claude|aider|codex|opencode|goose|crush|amp|cursor-agent)$'
```

`auto` splits beside the current pane when the window is at least 180 columns
wide, and below it otherwise. The corresponding `VIMIDE_AGENT_CMD`,
`VIMIDE_AGENT_SPLIT`, `VIMIDE_AGENT_RE` and `VIMIDE_AGENT_PANE` environment
variables win over the options when they are set, which is mostly useful for
one-off overrides from a shell.

### How the text gets there

Through a tmux buffer as a bracketed paste (`load-buffer` then `paste-buffer
-p`), not as typed keys. Newlines therefore stay newlines instead of submitting
a half-written prompt line by line, and there is no quoting or length limit to
worry about. `prefix P` uses `capture-pane -J`, which unwraps lines the
terminal had folded, so a long traceback line arrives in one piece.

The prefix bindings pass `SELF_PANE=#{pane_id}` because `run-shell` sets `TMUX`
but not `TMUX_PANE` -- it has no pane of its own.

Troubleshooting
---------------

| Symptom | Cause |
| --- | --- |
| Mouse scrolling stops working after `prefix r` | a flag option set with no value *toggles*. `set -g mouse` (no value) flips the mouse off on one reload and back on with the next. It is `set -g mouse on` here for exactly that reason -- if you copy a line like that in from somewhere, give it a value |
| `prefix a`/`A`/`P` do nothing | `~/bin/agent-pane` is not there yet; run `./createLinks.sh` |
| `agent-pane: not inside tmux` | it was run outside tmux. `--help` still works there |
| tmux will not start: "missing or unsuitable terminal" | no `tmux-256color` terminfo; run `./createLinks.sh`, or the `tic` line above |
| Copy-mode yanks do not reach the system clipboard | no backend installed (`wl-clipboard` or `xclip`), or tmux is older than 3.2. Check `tmux show-options -sv copy-command` |
| `C-l` no longer clears the screen | taken by pane navigation; use `prefix C-l`, or `prefix k` to clear the scrollback too |
| Colours look flat in vim | the outer terminal is not passing truecolor, or tmux is older than 3.2 (no `terminal-features`) |
