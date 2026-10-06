#!/usr/bin/env bash
# Installation script for Google Tasks plugin on Omarchy Linux

set -euo pipefail

PLUGIN_ID="bmclain.google-tasks"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
CONFIG_DIR="$HOME/.config/omarchy/google-tasks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing Google Tasks Plugin for Omarchy ==="

# 1. Install plugin files
mkdir -p "$PLUGIN_DIR/bin"
cp "$SCRIPT_DIR/manifest.json" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/Panel.qml" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/CalendarPicker.qml" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/CalendarUtils.js" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/bin/tasks-cli" "$PLUGIN_DIR/bin/"
chmod +x "$PLUGIN_DIR/bin/tasks-cli"

echo "✓ Plugin files installed to $PLUGIN_DIR"

# 2. Setup Google OAuth Credentials
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/credentials.json" ]; then
  echo ""
  echo "Google OAuth credentials are required to connect to Google Tasks."
  echo "You can create desktop app OAuth credentials in Google Cloud Console."
  read -rp "Enter Google Client ID: " CLIENT_ID
  read -rp "Enter Google Client Secret: " CLIENT_SECRET

  if [ -n "$CLIENT_ID" ] && [ -n "$CLIENT_SECRET" ]; then
    cat > "$CONFIG_DIR/credentials.json" <<EOF
{
  "client_id": "$CLIENT_ID",
  "client_secret": "$CLIENT_SECRET"
}
EOF
    chmod 600 "$CONFIG_DIR/credentials.json"
    echo "✓ Credentials saved to $CONFIG_DIR/credentials.json"
  else
    echo "⚠ No credentials entered. You can configure them later at $CONFIG_DIR/credentials.json or by running:"
    echo "  $PLUGIN_DIR/bin/tasks-cli setup"
  fi
else
  echo "✓ Existing credentials found at $CONFIG_DIR/credentials.json"
fi

# 3. Add keybinding to Hyprland
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
if [ -f "$BINDINGS_FILE" ]; then
  if ! grep -q "SUPER + SHIFT + T" "$BINDINGS_FILE"; then
    echo "" >> "$BINDINGS_FILE"
    echo "-- Google Tasks" >> "$BINDINGS_FILE"
    echo 'o.bind("SUPER + SHIFT + T", "Google Tasks", "omarchy-shell google-tasks toggle")' >> "$BINDINGS_FILE"
    echo "✓ Keybinding SUPER + SHIFT + T added to $BINDINGS_FILE"
    if command -v hyprctl &>/dev/null; then
      hyprctl reload >/dev/null 2>&1 || true
    fi
  else
    echo "✓ Keybinding SUPER + SHIFT + T already present"
  fi
fi

# 4. Enable plugin in Omarchy
if command -v omarchy &>/dev/null; then
  omarchy plugin enable "$PLUGIN_ID" || true
  omarchy restart shell || true
fi

# 5. Configure Antigravity MCP server if ~/.gemini/config exists
MCP_CONFIG="$HOME/.gemini/config/mcp_config.json"
if [ -d "$HOME/.gemini/config" ]; then
  if command -v jq &>/dev/null; then
    if [ ! -f "$MCP_CONFIG" ] || [ ! -s "$MCP_CONFIG" ]; then
      cat > "$MCP_CONFIG" <<EOF
{
  "mcpServers": {
    "google-tasks": {
      "command": "$PLUGIN_DIR/bin/tasks-cli",
      "args": ["mcp"]
    }
  }
}
EOF
    else
      jq --arg cmd "$PLUGIN_DIR/bin/tasks-cli" '.mcpServers["google-tasks"] = { command: $cmd, args: ["mcp"] }' "$MCP_CONFIG" > "${MCP_CONFIG}.tmp" && mv "${MCP_CONFIG}.tmp" "$MCP_CONFIG"
    fi
    echo "✓ Google Tasks MCP server configured in $MCP_CONFIG"
  fi
fi

echo ""
echo "=== Installation Complete! ==="
echo "Press SUPER + SHIFT + T or click the Tasks icon in your top bar to open Google Tasks."
echo "If not yet authenticated, click 'Sign In with Google' to connect your account."
