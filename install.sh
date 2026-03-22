#!/usr/bin/env bash
#
# Pyth Entropy Skill — One-Command Installer (macOS/Linux)
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/MJD2003/pyth-entropy-skill/main/install.sh | bash
#
# Or locally:
#   bash install.sh [--windsurf] [--cursor] [--claude] [--project /path/to/project]
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

REPO_URL="https://github.com/MJD2003/pyth-entropy-skill.git"
SKILL_NAME="pyth-entropy"

# ─── Parse args ──────────────────────────────────────────

INSTALL_WINDSURF=false
INSTALL_CURSOR=false
INSTALL_CLAUDE=false
PROJECT_DIR=""

for arg in "$@"; do
    case $arg in
        --windsurf) INSTALL_WINDSURF=true ;;
        --cursor)   INSTALL_CURSOR=true ;;
        --claude)   INSTALL_CLAUDE=true ;;
        --project)  shift; PROJECT_DIR="$1" ;;
        --project=*) PROJECT_DIR="${arg#*=}" ;;
        --all)      INSTALL_WINDSURF=true; INSTALL_CURSOR=true; INSTALL_CLAUDE=true ;;
        --help)
            echo "Usage: install.sh [--windsurf] [--cursor] [--claude] [--all] [--project /path]"
            echo ""
            echo "  --windsurf   Install as Windsurf/Cascade skill"
            echo "  --cursor     Copy .cursorrules to current or specified project"
            echo "  --claude     Install as Claude Code plugin"
            echo "  --all        Install for all supported IDEs"
            echo "  --project    Target project directory (for cursor/claude)"
            exit 0
            ;;
    esac
done

# If no flags, auto-detect
if ! $INSTALL_WINDSURF && ! $INSTALL_CURSOR && ! $INSTALL_CLAUDE; then
    echo -e "${CYAN}${BOLD}🎲 Pyth Entropy Skill Installer${NC}"
    echo ""
    echo "Which IDE(s) do you want to install for?"
    echo "  1) Windsurf / Cascade"
    echo "  2) Cursor"
    echo "  3) Claude Code"
    echo "  4) All of the above"
    echo "  5) Just clone the repo (manual setup)"
    echo ""
    read -p "Choose [1-5]: " choice
    case $choice in
        1) INSTALL_WINDSURF=true ;;
        2) INSTALL_CURSOR=true ;;
        3) INSTALL_CLAUDE=true ;;
        4) INSTALL_WINDSURF=true; INSTALL_CURSOR=true; INSTALL_CLAUDE=true ;;
        5) ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

# ─── Clone or update ─────────────────────────────────────

TEMP_DIR=$(mktemp -d)
SKILL_SOURCE="$TEMP_DIR/$SKILL_NAME"

echo -e "${CYAN}Cloning Pyth Entropy skill...${NC}"
if command -v git &>/dev/null; then
    git clone --depth 1 "$REPO_URL" "$SKILL_SOURCE" 2>/dev/null || {
        echo -e "${YELLOW}Git clone failed. Trying to use local copy...${NC}"
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        SKILL_SOURCE="$SCRIPT_DIR"
    }
else
    echo -e "${RED}Git not found. Please install git or clone manually.${NC}"
    exit 1
fi

# ─── Windsurf Install ────────────────────────────────────

if $INSTALL_WINDSURF; then
    echo ""
    echo -e "${CYAN}Installing for Windsurf/Cascade...${NC}"

    WINDSURF_SKILLS="$HOME/.codeium/windsurf/skills"
    mkdir -p "$WINDSURF_SKILLS"

    DEST="$WINDSURF_SKILLS/$SKILL_NAME"
    if [ -d "$DEST" ]; then
        echo -e "${YELLOW}Updating existing installation at $DEST${NC}"
        rm -rf "$DEST"
    fi

    cp -r "$SKILL_SOURCE" "$DEST"
    echo -e "${GREEN}✓ Installed to $DEST${NC}"
    echo -e "  Windsurf will auto-discover the skill via SKILL.md"
fi

# ─── Cursor Install ──────────────────────────────────────

if $INSTALL_CURSOR; then
    echo ""
    echo -e "${CYAN}Installing for Cursor...${NC}"

    TARGET="${PROJECT_DIR:-.}"

    if [ ! -d "$TARGET" ]; then
        echo -e "${RED}Project directory not found: $TARGET${NC}"
        echo "Use --project /path/to/your/project"
    else
        # Copy .cursorrules
        cp "$SKILL_SOURCE/.cursorrules" "$TARGET/.cursorrules"
        echo -e "${GREEN}✓ Copied .cursorrules to $TARGET/${NC}"

        # Copy .cursor/rules/ directory
        mkdir -p "$TARGET/.cursor/rules"
        cp "$SKILL_SOURCE/.cursor/rules/pyth-entropy.md" "$TARGET/.cursor/rules/pyth-entropy.md"
        echo -e "${GREEN}✓ Copied .cursor/rules/pyth-entropy.md${NC}"

        echo -e "  Cursor will load the rules when working on matching files"
    fi
fi

# ─── Claude Code Install ─────────────────────────────────

if $INSTALL_CLAUDE; then
    echo ""
    echo -e "${CYAN}Installing for Claude Code...${NC}"

    TARGET="${PROJECT_DIR:-.}"

    if [ ! -d "$TARGET" ]; then
        echo -e "${RED}Project directory not found: $TARGET${NC}"
    else
        # Copy .claude directory
        mkdir -p "$TARGET/.claude/commands"
        cp "$SKILL_SOURCE/.claude/CLAUDE.md" "$TARGET/.claude/CLAUDE.md"
        cp "$SKILL_SOURCE/.claude/commands/entropy.md" "$TARGET/.claude/commands/entropy.md"
        echo -e "${GREEN}✓ Copied .claude/CLAUDE.md and commands/entropy.md to $TARGET/${NC}"

        # Also copy the full skill for reference access
        SKILL_DEST="$TARGET/.claude/skills/$SKILL_NAME"
        mkdir -p "$SKILL_DEST"
        cp -r "$SKILL_SOURCE/references" "$SKILL_DEST/"
        cp -r "$SKILL_SOURCE/assets" "$SKILL_DEST/"
        cp "$SKILL_SOURCE/SKILL.md" "$SKILL_DEST/"
        echo -e "${GREEN}✓ Copied full skill to $SKILL_DEST/${NC}"

        echo -e "  Use ${BOLD}/entropy${NC} command in Claude Code to integrate"
    fi
fi

# ─── Cleanup ─────────────────────────────────────────────

if [ "$SKILL_SOURCE" != "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" ]; then
    rm -rf "$TEMP_DIR"
fi

echo ""
echo -e "${GREEN}${BOLD}🎲 Pyth Entropy skill installed!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open your project in your IDE"
echo '  2. Tell your AI: "Add Pyth Entropy to my project"'
echo "  3. It will auto-detect your stack and generate adapted code"
echo ""
echo -e "Docs: ${CYAN}https://docs.pyth.network/entropy${NC}"
