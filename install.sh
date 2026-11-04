#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTRY="$SCRIPT_DIR/dist/index.js"
CLAUDE_SKILL_DIR="$HOME/.claude/skills/trello-update"
OPENCODE_DIR="$HOME/.config/opencode"
OPENCODE_JSON="$OPENCODE_DIR/opencode.json"

echo "trello-mcp-connector — Dual Installer (Claude Code + OpenCode)"
echo "=============================================================="

# 1. Install skill for Claude Code
mkdir -p "$CLAUDE_SKILL_DIR"
cp "$SCRIPT_DIR/skills/trello-update/SKILL.md" "$CLAUDE_SKILL_DIR/SKILL.md"
echo "  [Claude Code] Installed skill at $CLAUDE_SKILL_DIR/SKILL.md"

if [ "${TRELLO_SKIP_CLAUDE_CLI:-0}" != "1" ] && command -v claude >/dev/null 2>&1; then
  claude mcp remove -s user trello 2>/dev/null || true
  claude mcp add trello --scope user -- node "$ENTRY"
  echo "  [Claude Code] Registered trello MCP server"
else
  echo "  [Claude Code] Skipped CLI registration (or use: claude mcp add trello --scope user -- node $ENTRY)"
fi

# 2. Configure OpenCode MCP & skill path
mkdir -p "$OPENCODE_DIR"
SKILLS_PATH="$SCRIPT_DIR/skills"
if command -v jq >/dev/null 2>&1; then
  if [ -f "$OPENCODE_JSON" ]; then
    cp "$OPENCODE_JSON" "$OPENCODE_JSON.bak"
    jq --arg entry "$ENTRY" --arg sp "$SKILLS_PATH" '
      .mcp //= {} |
      .mcp.trello = {
        "type": "local",
        "command": ["node", $entry],
        "enabled": true
      } |
      .skills //= {} |
      .skills.paths //= [] |
      if (.skills.paths | index($sp)) then . else .skills.paths += [$sp] end
    ' "$OPENCODE_JSON.bak" > "$OPENCODE_JSON"
  else
    jq -n --arg entry "$ENTRY" --arg sp "$SKILLS_PATH" '{
      "$schema": "https://opencode.ai/config.json",
      "mcp": {
        "trello": {
          "type": "local",
          "command": ["node", $entry],
          "enabled": true
        }
      },
      "skills": {
        "paths": [$sp]
      }
    }' > "$OPENCODE_JSON"
  fi
  echo "  [OpenCode] Registered trello MCP server and skill path in $OPENCODE_JSON"
fi

echo ""
echo "Done. Restart Claude Code / OpenCode to use trello."
