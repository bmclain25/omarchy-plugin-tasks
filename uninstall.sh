#!/usr/bin/env bash
# Uninstallation script for Google Tasks plugin on Omarchy Linux

set -euo pipefail

PLUGIN_ID="bmclain.google-tasks"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"

echo "=== Uninstalling Google Tasks Plugin ==="

# 1. Disable plugin in Omarchy
if command -v omarchy &>/dev/null; then
  omarchy plugin disable "$PLUGIN_ID" || true
fi

# 2. Remove plugin directory
if [ -d "$PLUGIN_DIR" ]; then
  rm -rf "$PLUGIN_DIR"
  echo "✓ Removed $PLUGIN_DIR"
fi

# 3. Remove keybinding from Hyprland
if [ -f "$BINDINGS_FILE" ]; then
  sed -i '/-- Google Tasks/d' "$BINDINGS_FILE"
  sed -i '/SUPER + SHIFT + T.*Google Tasks/d' "$BINDINGS_FILE"
  if command -v hyprctl &>/dev/null; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
  echo "✓ Removed keybinding from $BINDINGS_FILE"
fi

# 4. Remove from MCP config if present
MCP_CONFIG="$HOME/.gemini/config/mcp_config.json"
if [ -f "$MCP_CONFIG" ] && command -v jq &>/dev/null; then
  jq 'del(.mcpServers["google-tasks"])' "$MCP_CONFIG" > "${MCP_CONFIG}.tmp" && mv "${MCP_CONFIG}.tmp" "$MCP_CONFIG"
  echo "✓ Removed from MCP config"
fi

if command -v omarchy &>/dev/null; then
  omarchy restart shell || true
fi

echo "=== Google Tasks plugin successfully uninstalled ==="
