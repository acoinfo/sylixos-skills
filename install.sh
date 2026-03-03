#!/usr/bin/env bash
# install.sh — Install sylixos-dev skill globally
#
# Skills follow the open agent skills standard. Installing to ~/.agents/skills/
# makes the skill available to all compatible agents (Claude Code, Codex, OpenClaw, etc.)
#
# Usage:
#   git clone https://github.com/SeanPcWoo/sylixos-dev.git && cd sylixos-dev && bash install.sh

set -euo pipefail

SKILL_NAME="sylixos-dev"
REPO_URL="https://github.com/SeanPcWoo/sylixos-dev.git"
INSTALL_DIR="$HOME/.agents/skills/$SKILL_NAME"

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
    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT
    info "Cloning $REPO_URL ..."
    git clone --depth=1 "$REPO_URL" "$TMPDIR/$SKILL_NAME" 2>/dev/null
    SOURCE_DIR="$TMPDIR/$SKILL_NAME"
    info "Installing from cloned repo"
fi

info "Installing to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
rsync -a --delete --exclude='.git' --exclude='install.sh' "$SOURCE_DIR/" "$INSTALL_DIR/"

echo ""
echo -e "${BOLD}${GREEN}Installation complete!${NC}"
echo ""
echo "  Location: $INSTALL_DIR"
echo ""
echo "This skill is now available globally from any directory for all"
echo "compatible agents (Claude Code, Codex, OpenClaw, etc.)."
echo ""
echo "Trigger it with: 创建 workspace, build, 编译, deploy, 部署, etc."
