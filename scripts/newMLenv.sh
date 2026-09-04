#!/usr/bin/env bash
#
# Create a Python virtualenv preloaded with a PyTorch + scientific stack.
# Uses uv (https://docs.astral.sh/uv/) for both the interpreter and the install.
#
#   newMLenv                        # venv named "mlenv"
#   newMLenv myproj                 # named venv
#   newMLenv myproj --no-torch      # scientific/plotting stack only
#   newMLenv myproj --no-jupyter    # skip jupyterlab/notebook/ipywidgets
#   newMLenv myproj --dev           # add ruff + mypy (what ALE lints with)
#   newMLenv myproj --python 3.13   # override detection; uv fetches it if absent
#   newMLenv myproj --dry-run       # print what would happen
#
# With no --python, the highest CPython already installed on the system that
# meets the floor below is used; nothing is downloaded.
#
# Anything after `--` is passed through to `uv venv`.
# Envs live under $VENV_HOME (default ~/.venvs), which the `activate` helper
# in bash_aliases completes over.

set -euo pipefail

VENV_HOME="${VENV_HOME:-$HOME/.venvs}"

NAME=''
PYVER=''
WANT_TORCH=1
WANT_JUPYTER=1
WANT_DEV=0
DRY_RUN=0
EXTRA=()

die() { printf 'newMLenv: %s\n' "$1" >&2; exit 1; }
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  would run:  %s\n' "$*"
    else
        printf '==> %s\n' "$*"
        "$@"
    fi
}

usage() { sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,2\} \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
    case "$1" in
        --no-torch)    WANT_TORCH=0 ;;
        --no-jupyter)  WANT_JUPYTER=0 ;;
        --dev)         WANT_DEV=1 ;;
        --python)      shift; PYVER="${1:-}"; [ -n "$PYVER" ] || die "--python needs a version" ;;
        --python=*)    PYVER="${1#*=}" ;;
        -n|--dry-run)  DRY_RUN=1 ;;
        -h|--help)     usage ;;
        --)            shift; EXTRA+=("$@"); break ;;
        -*)            die "unknown option: $1 (try --help)" ;;
        *)             if [ -z "$NAME" ]; then NAME="$1"; else die "unexpected argument: $1"; fi ;;
    esac
    shift
done

NAME="${NAME:-mlenv}"
TARGET="$VENV_HOME/$NAME"

command -v uv >/dev/null 2>&1 || die "uv not found. Install it with:
    brew install uv                                  # macOS
    curl -LsSf https://astral.sh/uv/install.sh | sh  # Linux"

# ------------------------------------------------------------ interpreter ---
# torch has published no wheel below this, so an older interpreter cannot
# resolve the stack at all.
MIN_PY_MINOR=10

# Highest CPython already present on this machine that clears the floor.
# Parses `uv python list`, which reports every interpreter it can see --
# system, Homebrew, pyenv and uv-managed alike.
detect_python() {
    uv python list --only-installed 2>/dev/null \
    | sed -n 's/^cpython-\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)-.*/\1/p' \
    | sort -u -t. -k1,1n -k2,2n -k3,3n \
    | awk -F. -v min="$MIN_PY_MINOR" '$1 == 3 && $2 >= min' \
    | tail -1
}

PYSOURCE='detected'
if [ -z "$PYVER" ]; then
    PYVER="$(detect_python || true)"
    if [ -z "$PYVER" ]; then
        PYSOURCE="uv default (nothing >= 3.$MIN_PY_MINOR found installed)"
    fi
else
    PYSOURCE='requested'
fi

# ---------------------------------------------------------------- packages ---
PKGS=(numpy scipy matplotlib seaborn bokeh pillow tqdm
      scikit-image scikit-video opencv-python opencv-contrib-python)

[ "$WANT_TORCH" -eq 1 ] && PKGS+=(torch torchvision)

# On JupyterLab 4 / Notebook 7, ipywidgets is all that is needed. The old
# `jupyter nbextension enable --py widgetsnbextension` and
# `jupyter labextension install @jupyter-widgets/jupyterlab-manager` steps
# were removed upstream; prebuilt extensions ship via pip now.
[ "$WANT_JUPYTER" -eq 1 ] && PKGS+=(jupyterlab notebook ipywidgets)

# ALE picks these up out of the venv (see g:ale_python_auto_virtualenv).
[ "$WANT_DEV" -eq 1 ] && PKGS+=(ruff mypy)

# Deliberately no longer installed:
#   tensorflow         -- PyTorch is the stack here now, and it publishes no
#                         wheel above cp313 so it blocks newer interpreters
#   tensorflow-addons  -- end of life since May 2024, no longer resolvable
#
# scikit-video is kept: last released in 2017 and unmaintained, but it still
# installs and imports cleanly against numpy 2.x. It needs ffmpeg on PATH.

# ------------------------------------------------------------------- build ---
printf 'Creating %s\n' "$TARGET"
printf '  python   : %s (%s)\n' "${PYVER:-uv default}" "$PYSOURCE"
printf '  packages : %s\n' "${PKGS[*]}"
[ "$DRY_RUN" -eq 1 ] && printf '  (dry run -- nothing will be created)\n'

if [ -e "$TARGET" ] && [ "$DRY_RUN" -eq 0 ]; then
    die "$TARGET already exists. Remove it first, or choose another name."
fi

[ -d "$VENV_HOME" ] || run mkdir -p "$VENV_HOME"

if [ -n "$PYVER" ]; then
    run uv venv --python "$PYVER" ${EXTRA[@]+"${EXTRA[@]}"} "$TARGET"
else
    run uv venv ${EXTRA[@]+"${EXTRA[@]}"} "$TARGET"
fi

# One resolve for the whole set, so a conflict surfaces now rather than
# halfway through building the environment.
run uv pip install --python "$TARGET/bin/python" "${PKGS[@]}"

# `source .../activate` from inside a script only affects that script's own
# shell and is gone the moment it exits -- which is what the old version did,
# silently achieving nothing. Print the command instead.
if [ "$DRY_RUN" -eq 1 ]; then
    printf '\n(dry run -- nothing was created)\n'
    exit 0
fi

cat <<MSG

Done. Activate it with:

    activate $NAME          # the helper in bash_aliases
    # or
    source $TARGET/bin/activate
MSG
