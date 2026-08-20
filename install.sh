#!/usr/bin/env bash
#
# WhatMark? installer for Linux and macOS.
#
#   1. checks Python 3.10+
#   2. checks Ollama, installs it if missing
#   3. checks the model, pulls it if missing
#   4. copies the skill to ~/.claude/skills/whatmark
#   5. creates the workspace ~/ClaudeText
#
# Usage:
#   ./install.sh
#   ./install.sh --yes --model llama3.2
#   ./install.sh --workspace /srv/whatmark

set -euo pipefail

MODEL="mistral"
WORKSPACE="${HOME}/ClaudeText"
ASSUME_YES=0

# ------------------------------------------------------------------ colors

if [ -t 1 ]; then
    C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m';  C_BOLD=$'\033[1m';   C_OFF=$'\033[0m'
else
    C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_OFF=""
fi

step() { printf '\n%s==> %s%s\n' "$C_CYAN" "$1" "$C_OFF"; }
ok()   { printf '    %s[ok]%s %s\n' "$C_GREEN" "$C_OFF" "$1"; }
warn() { printf '    %s[!]%s  %s\n' "$C_YELLOW" "$C_OFF" "$1"; }

die() {
    printf '\n%s[ERROR]%s %s\n' "$C_RED" "$C_OFF" "$1" >&2
    [ $# -gt 1 ] && printf '        %s%s%s\n' "$C_YELLOW" "$2" "$C_OFF" >&2
    printf '\n' >&2
    exit 1
}

confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    printf '    %s [y/N] ' "$1"
    read -r reply </dev/tty
    [[ "$reply" =~ ^[yY]$ ]]
}

# ------------------------------------------------------------------ args

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)       ASSUME_YES=1; shift ;;
        -m|--model)     MODEL="${2:?--model requires a value}"; shift 2 ;;
        -w|--workspace) WORKSPACE="${2:?--workspace requires a value}"; shift 2 ;;
        -h|--help)
            sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) die "Unknown option: $1" "Use --help for the list of options." ;;
    esac
done

REPO_URL="https://github.com/Uriel-SG/whatmark-skill.git"
REPO_ARCHIVE_URL="https://github.com/Uriel-SG/whatmark-skill/archive/refs/heads/main.tar.gz"
CHECKOUT_DIR="${WHATMARK_CHECKOUT_DIR:-$HOME/whatmark-skill}"

# When the script is cloned by hand, "skill/" sits right next to it. When it
# comes from a one-liner (curl | bash) instead, there's no file on disk to
# anchor to: the whole repository needs to be downloaded first.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"

printf '\n  %sWhatMark? - installer%s\n' "$C_BOLD" "$C_OFF"
printf '  ---------------------\n'

if [ -z "$SCRIPT_DIR" ] || [ ! -f "${SCRIPT_DIR}/skill/SKILL.md" ]; then
    step "Downloading the repository"

    if [ -f "${CHECKOUT_DIR}/skill/SKILL.md" ]; then
        ok "checkout already present in $CHECKOUT_DIR"
    else
        mkdir -p "$CHECKOUT_DIR"
        if command -v git >/dev/null 2>&1; then
            git clone --depth 1 "$REPO_URL" "$CHECKOUT_DIR" \
                || die "Repository clone failed." "Check your connection and try again."
        elif command -v curl >/dev/null 2>&1; then
            curl -fsSL "$REPO_ARCHIVE_URL" -o /tmp/whatmark-skill.tar.gz \
                || die "Repository download failed." "Check your connection and try again."
            tar -xzf /tmp/whatmark-skill.tar.gz -C "$CHECKOUT_DIR" --strip-components=1
            rm -f /tmp/whatmark-skill.tar.gz
        else
            die "Neither git nor curl is available." "Install one of them and try again."
        fi
        ok "downloaded to $CHECKOUT_DIR"
    fi

    SCRIPT_DIR="$CHECKOUT_DIR"
fi

printf '\n'
confirm "This skill requires Ollama and Mistral installed; if they are not already present, they will be installed automatically. Do you want to proceed?" \
    || die "Installation cancelled."

# ------------------------------------------------------------------ 1. python

step "Checking Python"

PY=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then
        if "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
            PY="$c"
            ok "$("$c" --version 2>&1)  (command: $c)"
            break
        fi
    fi
done

[ -n "$PY" ] || die "Python 3.10 or newer not found." \
    "Install it with your distro's package manager (e.g. apt install python3) or from https://www.python.org/downloads/"

# ------------------------------------------------------------------ 2. ollama

step "Checking Ollama installation..."

if command -v ollama >/dev/null 2>&1; then
    ok "already installed"
else
    warn "not found"

    if [ "$(uname -s)" = "Darwin" ]; then
        die "Automatic installation is not available on macOS." \
            "Download Ollama from https://ollama.com/download, install it, then re-run this script."
    fi

    command -v curl >/dev/null 2>&1 || die "curl is not available." \
        "Install it (e.g. apt install curl) and re-run this script."

    confirm "Install Ollama now?" || die "Installation cancelled." \
        "WhatMark? cannot work without Ollama."

    step "Installing Ollama"

    if ! curl -fsSL https://ollama.com/install.sh | sh; then
        die "Ollama installation failed." \
            "Try installing it manually from https://ollama.com/download"
    fi

    command -v ollama >/dev/null 2>&1 || die \
        "Ollama was installed but is not on the PATH." \
        "Open a new terminal and re-run this script."
    ok "installed"
fi

# ------------------------------------------------------------------ 3. service

step "Checking that Ollama is running"

ollama_up() { curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; }

if ! ollama_up; then
    warn "service not running, starting it in the background"
    nohup ollama serve >/tmp/whatmark-ollama.log 2>&1 &
    disown 2>/dev/null || true

    up=0
    for _ in $(seq 1 20); do
        sleep 1
        if ollama_up; then up=1; break; fi
    done

    [ "$up" -eq 1 ] || die \
        "Ollama is not responding on http://127.0.0.1:11434 after 20 seconds." \
        "Check the log at /tmp/whatmark-ollama.log and make sure port 11434 is free."
fi
ok "responding on http://127.0.0.1:11434"

# ------------------------------------------------------------------ 4. model

step "Checking model '$MODEL' installation..."

TAGS="$(curl -fsS --max-time 10 http://127.0.0.1:11434/api/tags)" \
    || die "Could not read the model list from Ollama."

if printf '%s' "$TAGS" | "$PY" -c "
import json,sys
m = sys.argv[1]
names = [x['name'] for x in json.load(sys.stdin).get('models', [])]
sys.exit(0 if any(n == m or n.startswith(m + ':') for n in names) else 1)
" "$MODEL"; then
    ok "already present"
else
    warn "not found"

    confirm "Install model '$MODEL' now?" || die "Download cancelled." \
        "You can do it later with:  ollama pull $MODEL"

    step "Installing model '$MODEL'"

    ollama pull "$MODEL" || die \
        "Model download failed." \
        "Check your connection and disk space, then retry with:  ollama pull $MODEL"
    ok "installed"
fi

# ------------------------------------------------------------------ 5. skill

step "Installing the skill"

SRC="${SCRIPT_DIR}/skill"
[ -d "$SRC" ] || die "'skill' folder not found next to install.sh." \
    "Run the script from the root of the cloned repository."

DEST="${HOME}/.claude/skills/whatmark"

mkdir -p "${DEST}/scripts" || die "Could not create $DEST"
cp "${SRC}/SKILL.md" "$DEST/" || die "Failed to copy SKILL.md."
cp "${SRC}/scripts/"*.py "${DEST}/scripts/" || die "Failed to copy the scripts."
chmod +x "${DEST}/scripts/"*.py

for f in SKILL.md scripts/ollama_translate.py scripts/compare_texts.py; do
    [ -f "${DEST}/${f}" ] || die "Missing file after copy: $f"
done
ok "$DEST"

# ------------------------------------------------------------------ 6. workspace

step "Workspace"

mkdir -p "$WORKSPACE" || die "Could not create $WORKSPACE" \
    "Choose a different folder with --workspace."
touch "${WORKSPACE}/.write_test" 2>/dev/null || die \
    "The folder $WORKSPACE is not writable." \
    "Check permissions, or use --workspace with a different path."
rm -f "${WORKSPACE}/.write_test"
ok "$WORKSPACE"

if [ "$WORKSPACE" != "${HOME}/ClaudeText" ]; then
    warn "non-default workspace: add this to your shell profile"
    echo "        export WHATMARK_DIR=\"$WORKSPACE\""
fi

# ------------------------------------------------------------------ 7. verify

step "Final check"

"$PY" "${DEST}/scripts/compare_texts.py" --help >/dev/null 2>&1 \
    || die "The Python scripts don't run." "Check that '$PY' works from this shell."
ok "scripts respond correctly"

printf '\n  %sInstallation complete.%s\n\n' "$C_GREEN" "$C_OFF"
printf '  Skill      : %s\n' "$DEST"
printf '  Workspace  : %s\n' "$WORKSPACE"
printf '  Model      : %s\n\n' "$MODEL"
printf '  Restart Claude Code, then type:\n'
printf '      %s/whatmark a 400-word post about Zero Trust%s\n\n' "$C_CYAN" "$C_OFF"
