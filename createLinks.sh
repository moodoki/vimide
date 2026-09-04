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

n_ok=0        # already correct
n_linked=0    # created or repaired
n_backed=0    # existing file moved aside
n_warn=0

# ---------------------------------------------------------------- output ---
if [ -t 1 ]; then
    c_ok=$'\033[32m'; c_new=$'\033[36m'; c_warn=$'\033[33m'; c_off=$'\033[0m'
else
    c_ok=''; c_new=''; c_warn=''; c_off=''
fi

ok()      { printf '%s  ok%s        %s\n'   "$c_ok"   "$c_off" "$1"; n_ok=$((n_ok + 1)); }
linked()  { printf '%s  linked%s    %s\n'   "$c_new"  "$c_off" "$1"; n_linked=$((n_linked + 1)); }
note()    { printf '  %s\n' "$1"; }
warn()    { printf '%s  warning%s   %s\n'   "$c_warn" "$c_off" "$1" >&2; n_warn=$((n_warn + 1)); }
section() { printf '\n%s\n' "$1"; }

usage() {
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,2\} \{0,1\}//'
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
            ok "${dst/#$HOME/~}"
            return 0
        fi
        # A symlink is only a pointer, so replacing it loses nothing.
        cur="$(readlink "$dst")"
        note "repointing ${dst/#$HOME/~} (was -> $cur)"
        act rm -f "$dst"
    elif [ -e "$dst" ]; then
        backup "$dst"
    fi

    act ln -s "$src" "$dst"
    linked "${dst/#$HOME/~} -> ${src#"$REPO"/}"
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
        'tmux:tmux:tmux:no:-V'
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

    if [ "$OS" = linux ] && ! command -v fc-cache >/dev/null 2>&1; then
        warn "fc-cache not found -- $(pkg_hint fontconfig fontconfig)"
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
        elif [ "$OS" = macos ]; then
            warn "~/bin is not on your PATH; add 'export PATH=\"\$HOME/bin:\$PATH\"' to ~/.zshrc"
        else
            warn "~/bin is not on your PATH; add it in your shell profile to use the scripts above"
        fi
        ;;
esac

if [ "$DO_FONTS" -eq 1 ]; then
    section 'Fonts'
    install_fonts
fi

section 'Summary'
printf '  %d already correct, %d linked, %d backed up, %d warnings\n' \
    "$n_ok" "$n_linked" "$n_backed" "$n_warn"
[ "$DRY_RUN" -eq 1 ] && printf '  (dry run -- nothing was changed)\n'
exit 0
