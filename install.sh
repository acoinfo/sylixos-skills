#!/usr/bin/env bash
# install.sh — Install sylixos-dev skill for Claude Code, Codex, and OpenClaw
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SeanPcWoo/sylixos-dev/main/install.sh | bash
#   # or
#   git clone https://github.com/SeanPcWoo/sylixos-dev.git && cd sylixos-dev && bash install.sh

set -euo pipefail

SKILL_NAME="sylixos-dev"
REPO_URL="https://github.com/SeanPcWoo/sylixos-dev.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Determine source: running from cloned repo or piped from curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ -f "$SCRIPT_DIR/SKILL.md" ]]; then
    SOURCE_DIR="$SCRIPT_DIR"
    info "Installing from local directory: $SOURCE_DIR"
else
    # Clone to temp directory
    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT
    info "Cloning $REPO_URL ..."
    git clone --depth=1 "$REPO_URL" "$TMPDIR/$SKILL_NAME" 2>/dev/null
    SOURCE_DIR="$TMPDIR/$SKILL_NAME"
    info "Installing from cloned repo"
fi

installed=0

# --- Claude Code: ~/.agents/skills/ ---
CLAUDE_DIR="$HOME/.agents/skills/$SKILL_NAME"
if command -v claude &>/dev/null || [[ -d "$HOME/.agents" ]]; then
    info "Installing for Claude Code → $CLAUDE_DIR"
    mkdir -p "$CLAUDE_DIR"
    rsync -a --delete --exclude='.git' --exclude='install.sh' "$SOURCE_DIR/" "$CLAUDE_DIR/"
    ok "Claude Code: installed"
    installed=$((installed + 1))
else
    info "Claude Code not detected, skipping (~/.agents not found)"
fi

# --- Codex: ~/.codex/skills/ ---
CODEX_DIR="$HOME/.codex/skills/$SKILL_NAME"
if command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; then
    info "Installing for Codex → $CODEX_DIR"
    mkdir -p "$CODEX_DIR"
    rsync -a --delete --exclude='.git' --exclude='install.sh' "$SOURCE_DIR/" "$CODEX_DIR/"
    ok "Codex: installed"
    installed=$((installed + 1))
else
    info "Codex not detected, skipping (~/.codex not found)"
fi

# --- Summary ---
echo ""
if [[ $installed -gt 0 ]]; then
    echo -e "${BOLD}${GREEN}Installation complete!${NC}"
    echo ""
    echo "Installed locations:"
    [[ -d "$CLAUDE_DIR" ]] && echo "  Claude Code: $CLAUDE_DIR"
    [[ -d "$CODEX_DIR" ]]  && echo "  Codex:       $CODEX_DIR"
    echo ""
    echo "The skill is now available globally from any directory."
    echo "Trigger it with: 创建 workspace, build, 编译, deploy, 部署, etc."
else
    err "No supported agent found. Please install Claude Code or Codex first."
    exit 1
fi
