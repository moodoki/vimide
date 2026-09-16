#!/usr/bin/env bash
#
# Idempotent installer for these dotfiles.
#
# Safe to re-run: links that already point at this repo are left alone, and
# anything real that is in the way is moved to a timestamped .bak- file rather
# than overwritten. Nothing is ever deleted.
#
#   ./createLinks.sh              install / repair
#   ./createLinks.sh --dry-run    show what would happen, change nothing
#   ./createLinks.sh --help       usage
#
# Opt out of any step with --no-submodules, --no-deps, --no-shell,
# --no-fonts or --no-terminfo.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# uname is more reliable than $OSTYPE, which some shells do not set.
case "$(uname -s)" in
    Darwin)  OS=macos   ;;
    Linux)   OS=linux   ;;
    *BSD)    OS=linux   ;;   # close enough: fontconfig + XDG
    *)       OS=unknown ;;
esac

# Ubuntu 24.04 is the primary Linux target; DISTRO tailors the hints below.
DISTRO=''
if [ "${OS:-}" = linux ] && [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    DISTRO="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")"
fi

# Honour the XDG vars on Linux; on macOS they are almost never set, so these
# fall back to the same ~/.config and ~/.local/share the defaults describe.
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

DRY_RUN=0
DO_SUBMODULES=1
DO_FONTS=1
DO_DEPS=1
DO_TERMINFO=1
DO_SHELL=1

n_ok=0        # already correct
n_linked=0    # created or repaired
n_backed=0    # existing file moved aside
n_edited=0    # shell rc appended to
n_warn=0

# ---------------------------------------------------------------- output ---
if [ -t 1 ]; then
    c_ok=$'\033[32m'; c_new=$'\033[36m'; c_warn=$'\033[33m'; c_off=$'\033[0m'
else
    c_ok=''; c_new=''; c_warn=''; c_off=''
fi

ok()      { printf '%s  ok%s        %s\n'   "$c_ok"   "$c_off" "$1"; n_ok=$((n_ok + 1)); }
linked()  { printf '%s  linked%s    %s\n'   "$c_new"  "$c_off" "$1"; n_linked=$((n_linked + 1)); }
created() { printf '%s  created%s   %s\n'   "$c_new"  "$c_off" "$1"; n_linked=$((n_linked + 1)); }
updated() { printf '%s  updated%s   %s\n'   "$c_new"  "$c_off" "$1"; n_edited=$((n_edited + 1)); }
note()    { printf '  %s\n' "$1"; }
warn()    { printf '%s  warning%s   %s\n'   "$c_warn" "$c_off" "$1" >&2; n_warn=$((n_warn + 1)); }
section() { printf '\n%s\n' "$1"; }

# Shorten a path for display. The obvious ${p/#$HOME/~} does not work: bash 5
# tilde-expands the replacement straight back into $HOME so nothing is
# shortened, and quoting the tilde to stop that leaves a literal backslash on
# bash 3.2, which is what Apple still ships as /bin/bash.
tilde() {
    case "$1" in
        "$HOME")   printf '~' ;;
        "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
        *)         printf '%s' "$1" ;;
    esac
}

usage() {
    awk 'NR == 1 { next }            # the shebang
         /^#/    { sub(/^#+ ?/, ""); print; next }
                 { exit }' "${BASH_SOURCE[0]}"
    exit 0
}

# Run a command, or just print it under --dry-run.
act() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  would run:  %s\n' "$*"
    else
        "$@"
    fi
}

# Create a directory once. Tracks what it has done so --dry-run does not
# print the same mkdir for every file that lands in the directory.
_made_dirs=''
ensure_dir() {
    local d="$1"
    [ -d "$d" ] && return 0
    case "$_made_dirs" in *"|$d|"*) return 0 ;; esac
    _made_dirs="${_made_dirs}|$d|"
    act mkdir -p "$d"
}

# ------------------------------------------------------------------ links ---

# Move an existing path out of the way, never clobbering a previous backup.
backup() {
    local path="$1" dest
    dest="${path}.bak-$(date +%Y%m%d%H%M%S)"
    while [ -e "$dest" ]; do dest="${dest}~"; done
    warn "$path exists; moving to $(basename "$dest")"
    act mv "$path" "$dest"
    n_backed=$((n_backed + 1))
}

# link <source-in-repo> <destination>
link() {
    local src="$1" dst="$2" parent cur

    if [ ! -e "$src" ]; then
        warn "source missing, skipping: ${src#"$REPO"/}"
        return 0
    fi

    parent="$(dirname "$dst")"
    ensure_dir "$parent"

    if [ -L "$dst" ]; then
        # -ef compares device+inode through the link, so a link reached by a
        # different but equivalent path (e.g. ~/code -> /Volumes/code) counts
        # as already correct and is left alone.
        if [ "$dst" -ef "$src" ]; then
            ok "$(tilde "$dst")"
            return 0
        fi
        # A symlink is only a pointer, so replacing it loses nothing.
        cur="$(readlink "$dst")"
        note "repointing $(tilde "$dst") (was -> $cur)"
        act rm -f "$dst"
    elif [ -e "$dst" ]; then
        backup "$dst"
    fi

    act ln -s "$src" "$dst"
    linked "$(tilde "$dst") -> ${src#"$REPO"/}"
}

# ------------------------------------------------------------------ shell ---
# Linking ~/.bash_aliases is only half the job -- something has to source it,
# and which file that is differs by platform. That difference is why this has
# always worked on Linux and quietly never worked on macOS:
#
#   Linux    a terminal window starts a non-login interactive bash, which
#            reads ~/.bashrc -- and Ubuntu's stock ~/.bashrc already ends with
#            an `if [ -f ~/.bash_aliases ]` block, so the aliases load by
#            luck rather than by anything this script did.
#   macOS    Terminal.app and iTerm2 start every window as a *login* shell,
#            which reads ~/.bash_profile (or ~/.bash_login, or ~/.profile --
#            the first of the three that exists) and never ~/.bashrc on its
#            own. Nothing on a stock macOS mentions ~/.bash_aliases at all.
#
# So the block goes in ~/.bashrc on both, and where the login file does not
# already chain to ~/.bashrc we add that too -- which also fixes nested
# non-login shells (a bare `bash`, `:!cmd` from vim) on macOS.

# The line that does the work, wrapped in markers so a re-run recognises it.
ALIASES_BLOCK='# >>> vimide >>>
[ -f "$HOME/.bash_aliases" ] && . "$HOME/.bash_aliases"
# <<< vimide <<<'

BASHRC_BLOCK='# >>> vimide >>>
# A terminal window starts bash as a login shell here, so this file is read
# and ~/.bashrc is not. Chain to it, the way the Linux distributions do.
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
# <<< vimide <<<'

# The file bash reads for a login shell: the first of these that exists.
# Order matters -- bash stops at the first hit, so a ~/.bash_profile shadows
# ~/.profile entirely.
login_rc() {
    local f
    for f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
        [ -f "$f" ] && { printf '%s' "$f"; return 0; }
    done
    return 1
}

# Paths that FILE sources, for `. x`, `source x`, and the `[ -s x ] && . x`
# form that does not start the line.
sourced_paths() {
    [ -r "$1" ] || return 0
    grep -oE '(^|[;&|[:space:]])(source|\.)[[:space:]]+[^[:space:];&|)]+' "$1" 2>/dev/null \
        | sed -e 's/.*[[:space:]]//' -e 's/^["'\'']//' -e 's/["'\'']$//'
}

# Does FILE mention PATTERN outside a comment, directly or through a file it
# sources? Static scan, deliberately: sourcing someone's profile to find out
# what it does is not a trade an installer should make.
rc_sources() {
    local file="$1" pattern="$2" depth="${3:-3}" p
    [ -r "$file" ] || return 1
    grep -qE "^[^#]*$pattern" "$file" 2>/dev/null && return 0
    [ "$depth" -le 0 ] && return 1
    while IFS= read -r p; do
        case "$p" in
            '~'/*)        p="$HOME/${p#\~/}" ;;
            '$HOME'/*)    p="$HOME/${p#\$HOME/}" ;;
            '${HOME}'/*)  p="$HOME/${p#\$\{HOME\}/}" ;;
            /*)           ;;
            *)            continue ;;   # relative or computed; not worth guessing
        esac
        rc_sources "$p" "$pattern" $((depth - 1)) && return 0
    done < <(sourced_paths "$file")
    return 1
}

# Append a block to a shell rc, keeping a copy of what was there first. Only
# ever adds to the end; nothing in the file is rewritten or removed.
append_block() {
    local file="$1" block="$2" label="$3" copy existed=1

    [ -e "$file" ] || existed=0

    if [ "$DRY_RUN" -eq 1 ]; then
        if [ "$existed" -eq 0 ]; then
            printf '  would create %s, %s\n' "$(tilde "$file")" "$label"
        else
            printf '  would append to %s, %s\n' "$(tilde "$file")" "$label"
        fi
        n_edited=$((n_edited + 1))
        return 0
    fi

    if [ "$existed" -eq 1 ]; then
        copy="${file}.bak-$(date +%Y%m%d%H%M%S)"
        while [ -e "$copy" ]; do copy="${copy}~"; done
        cp -p "$file" "$copy"
        note "kept a copy of $(basename "$file") as $(basename "$copy")"
    else
        ensure_dir "$(dirname "$file")"
    fi

    # The leading newline separates the block from whatever is above it, and
    # covers a file that does not end in one.
    printf '\n%s\n' "$block" >> "$file"
    updated "$(tilde "$file")  ($label)"
}

# Where a hint should tell you to put things, for whatever shell you use.
shell_rc_hint() {
    case "$(basename "${SHELL:-bash}")" in
        zsh)  printf '~/.zshrc' ;;
        bash) printf '~/.bashrc' ;;
        *)    printf "your shell's startup file" ;;
    esac
}

install_shell() {
    local rc="$HOME/.bashrc" login shell_name changed=0

    # bash_aliases is bash, not sh: `complete -F`, $COMP_WORDS and $COMPREPLY
    # have no zsh equivalent, so sourcing it from ~/.zshrc would raise errors
    # rather than help. Wire up bash regardless -- it is still what you get
    # from `bash`, from tmux panes and over ssh -- but say so.
    shell_name="$(basename "${SHELL:-bash}")"
    case "$shell_name" in
        bash) ;;
        *) warn "your login shell is $shell_name; bash_aliases is bash-only (complete -F, \$COMPREPLY) so it is not wired into it -- the aliases apply when you run bash" ;;
    esac

    if rc_sources "$rc" 'bash_aliases'; then
        ok "~/.bashrc sources ~/.bash_aliases"
    else
        append_block "$rc" "$ALIASES_BLOCK" 'sources ~/.bash_aliases'
        changed=1
    fi

    # Second half: is ~/.bashrc itself read?
    if login="$(login_rc)"; then
        if rc_sources "$login" '\.bashrc' 1; then
            ok "$(tilde "$login") sources ~/.bashrc"
        elif [ "$OS" = macos ]; then
            append_block "$login" "$BASHRC_BLOCK" 'sources ~/.bashrc'
            changed=1
        else
            # Terminal windows here read ~/.bashrc directly, so this only
            # costs you the aliases on a login shell -- ssh, a tty console.
            # Not worth editing a file the distribution owns uninvited.
            warn "$(tilde "$login") does not source ~/.bashrc, so login shells (ssh, console) will not see the aliases; terminal windows are unaffected. Add: [ -f ~/.bashrc ] && . ~/.bashrc"
        fi
    elif [ "$OS" = macos ]; then
        # No login file at all: every Terminal window would read nothing.
        append_block "$HOME/.bash_profile" "$BASHRC_BLOCK" 'sources ~/.bashrc'
        changed=1
    fi
    # Linux with no login file needs nothing: terminals read ~/.bashrc.

    if [ "$changed" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
        note "open a new shell, or run: . ~/.bashrc"
    fi
}

# ------------------------------------------------------------------ fonts ---
install_fonts() {
    local dir f

    if [ "$OS" = macos ]; then
        # macOS scans ~/Library/Fonts non-recursively, so each file is linked
        # individually; a linked directory would simply be ignored.
        dir="$HOME/Library/Fonts"
        ensure_dir "$dir"
        while IFS= read -r f; do
            link "$f" "$dir/$(basename "$f")"
        done < <(find "$REPO/fonts" -type f -name '*.ttf' | sort)

        if [ -e "$HOME/.fonts/vimide_fonts" ]; then
            warn "~/.fonts/vimide_fonts is a Linux-only leftover and does nothing on macOS; remove it when convenient"
        fi
        return 0
    fi

    # fontconfig (Linux/BSD) recurses, so one directory link is enough.
    # ~/.fonts is deprecated in favour of XDG, but keep using it if the
    # machine already has one so existing setups are not split in two.
    if [ -d "$HOME/.fonts" ]; then
        dir="$HOME/.fonts"
    else
        dir="$DATA_HOME/fonts"
    fi
    ensure_dir "$dir"
    link "$REPO/fonts" "$dir/vimide_fonts"

    if command -v fc-cache >/dev/null 2>&1; then
        act fc-cache -f "$dir"
    else
        warn "fc-cache not found; fonts linked but the cache was not rebuilt"
    fi
}

# --------------------------------------------------------------- terminfo ---
# tmux.conf sets default-terminal "tmux-256color". If that terminfo entry is
# absent, tmux refuses to start at all ("missing or unsuitable terminal") --
# not a degraded mode, a hard failure. ncurses has shipped the entry since 6.x,
# so on anything current this does nothing; older boxes (Ubuntu 20.04 and
# before, some minimal images) may need it compiled in.
#
# res/tmux-256color.terminfo is a plain `infocmp -x` dump, compiled per-user
# into ~/.terminfo, so no root is needed and no system file is touched.
install_terminfo() {
    local src="$REPO/res/tmux-256color.terminfo"

    if infocmp tmux-256color >/dev/null 2>&1; then
        ok "terminfo tmux-256color (already present)"
        return 0
    fi

    if [ ! -f "$src" ]; then
        warn "tmux-256color terminfo missing, and $src is not in the repo"
        return 0
    fi

    if ! command -v tic >/dev/null 2>&1; then
        warn "tmux-256color terminfo missing and tic not found -- $(pkg_hint ncurses ncurses-bin)"
        return 0
    fi

    ensure_dir "$HOME/.terminfo"
    act tic -x -o "$HOME/.terminfo" "$src"
    created "terminfo tmux-256color -> ~/.terminfo"
}

# ------------------------------------------------------------------- deps ---
# Report only. Installing packages is the user's call, not the script's.
pkg_hint() {
    if [ "$OS" = macos ]; then
        printf 'brew install %s' "$1"
    elif [ "$DISTRO" = ubuntu ] || [ "$DISTRO" = debian ]; then
        printf 'sudo apt install %s' "$2"
    else
        printf 'install %s' "$1"
    fi
}

check_deps() {
    local entry tool brew apt req flag ver

    # tool:brew-name:apt-name:required:version-flag
    for entry in \
        'git:git:git:yes:--version' \
        'vim:vim:vim:no:--version' \
        'nvim:neovim:neovim:no:--version' \
        'tmux:tmux:tmux:no:-V' \
        'uv:uv:uv:no:--version'
    do
        tool="${entry%%:*}"; entry="${entry#*:}"
        brew="${entry%%:*}"; entry="${entry#*:}"
        apt="${entry%%:*}";  entry="${entry#*:}"
        req="${entry%%:*}";  flag="${entry#*:}"

        if command -v "$tool" >/dev/null 2>&1; then
            ver="$("$tool" "$flag" 2>/dev/null | head -1 | cut -c1-45 || true)"
            ok "$tool ${ver:-(version unknown)}"
        elif [ "$req" = yes ]; then
            warn "$tool is required -- $(pkg_hint "$brew" "$apt")"
        else
            warn "$tool not found -- $(pkg_hint "$brew" "$apt")"
        fi
    done

    # tagbar needs universal-ctags (or the older exuberant-ctags). macOS ships
    # a BSD ctags in /usr/bin that looks present but cannot drive tagbar.
    if command -v ctags >/dev/null 2>&1; then
        ver="$(ctags --version 2>/dev/null | head -1 || true)"
        case "$ver" in
            *Universal*|*Exuberant*) ok "ctags $(printf '%s' "$ver" | cut -c1-45)" ;;
            *) warn "ctags is the BSD version ($(command -v ctags)); tagbar needs universal-ctags -- $(pkg_hint universal-ctags universal-ctags)" ;;
        esac
    else
        warn "ctags not found; tagbar will not work -- $(pkg_hint universal-ctags universal-ctags)"
    fi

    # tmux.conf pipes copy-mode yanks through this wrapper, which has been
    # unnecessary since macOS 10.12 / tmux 2.6. Only complain while the config
    # still asks for it, so the warning disappears once tmux.conf is fixed.
    if [ "$OS" = macos ] \
        && grep -q 'reattach-to-user-namespace' "$REPO/tmux.conf" 2>/dev/null \
        && ! command -v reattach-to-user-namespace >/dev/null 2>&1
    then
        warn "tmux.conf pipes copy-mode yanks through reattach-to-user-namespace, which is not installed; copying to the clipboard from tmux will do nothing. Replace it with plain pbcopy in tmux.conf"
    fi

    if [ "$OS" = linux ] && ! command -v fc-cache >/dev/null 2>&1; then
        warn "fc-cache not found -- $(pkg_hint fontconfig fontconfig)"
    fi

    if ! command -v uv >/dev/null 2>&1; then
        if [ "$OS" = macos ]; then
            warn "uv not found (needed by newMLenv) -- brew install uv"
        else
            warn "uv not found (needed by newMLenv) -- curl -LsSf https://astral.sh/uv/install.sh | sh"
        fi
    fi

    # scripts/newMLenv.sh needs the venv module, which Ubuntu ships separately.
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -c 'import venv' >/dev/null 2>&1; then
            warn "python3 venv module missing -- $(pkg_hint python python3-venv) (needed by newMLenv)"
        fi
    else
        warn "python3 not found -- $(pkg_hint python python3)"
    fi

    return 0
}

# ------------------------------------------------------------------- main ---
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run)   DRY_RUN=1 ;;
        --no-submodules) DO_SUBMODULES=0 ;;
        --no-fonts)     DO_FONTS=0 ;;
        --no-deps)      DO_DEPS=0 ;;
        --no-terminfo)  DO_TERMINFO=0 ;;
        --no-shell)     DO_SHELL=0 ;;
        -h|--help)      usage ;;
        *) printf 'unknown option: %s (try --help)\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

printf 'Installing from %s\n' "$REPO"
printf 'Platform: %s%s\n' "$OS" "${DISTRO:+ ($DISTRO)}"
[ "$DRY_RUN" -eq 1 ] && printf '(dry run -- nothing will be changed)\n'

if [ "$DO_DEPS" -eq 1 ]; then
    section 'Dependencies'
    check_deps
fi

if [ "$DO_SUBMODULES" -eq 1 ]; then
    section 'Submodules'
    if [ -d "$REPO/.git" ] || [ -f "$REPO/.git" ]; then
        # sync picks up any URL changes in .gitmodules on an existing clone.
        act git -C "$REPO" submodule sync --recursive
        act git -C "$REPO" submodule update --init --recursive
    else
        warn "not a git checkout; skipping submodules"
    fi
fi

section 'Config files'
link "$REPO/vim"          "$HOME/.vim"
link "$REPO/vimrc"        "$HOME/.vimrc"
link "$REPO/nvim_config"  "$CONFIG_HOME/nvim"
link "$REPO/bash_aliases" "$HOME/.bash_aliases"
link "$REPO/tmux.conf"    "$HOME/.tmux.conf"

if [ "$DO_SHELL" -eq 1 ]; then
    section 'Shell'
    install_shell
fi

section 'Scripts'
for s in "$REPO"/scripts/*; do
    [ -f "$s" ] || continue
    name="$(basename "$s")"
    link "$s" "$HOME/bin/${name%.*}"
done

case ":${PATH:-}:" in
    *":$HOME/bin:"*) ;;
    *)
        if [ "$DISTRO" = ubuntu ] || [ "$DISTRO" = debian ]; then
            # Ubuntu's stock ~/.profile prepends ~/bin, but only if the
            # directory already existed when the session started.
            warn "~/bin is not on your PATH yet; ~/.profile adds it at login, so log out and back in (or run: . ~/.profile)"
        else
            warn "~/bin is not on your PATH; add 'export PATH=\"\$HOME/bin:\$PATH\"' to $(shell_rc_hint) to use the scripts above"
        fi
        ;;
esac

if [ "$DO_FONTS" -eq 1 ]; then
    section 'Fonts'
    install_fonts
fi

if [ "$DO_TERMINFO" -eq 1 ]; then
    section 'Terminfo'
    install_terminfo
fi

section 'Summary'
printf '  %d already correct, %d linked, %d updated, %d backed up, %d warnings\n' \
    "$n_ok" "$n_linked" "$n_edited" "$n_backed" "$n_warn"
[ "$DRY_RUN" -eq 1 ] && printf '  (dry run -- nothing was changed)\n'
exit 0
