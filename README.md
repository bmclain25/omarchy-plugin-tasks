#  Google Tasks Plugin for Omarchy Linux

A native, high-performance **Google Tasks** bar widget and popout panel for [Omarchy](https://omarchy.org/) Linux (Arch Linux + Hyprland + Quickshell), featuring calendar date picking and Model Context Protocol (MCP) server integration for AI coding assistants.

---

## ✨ Features

- 🖥️ **Native Omarchy Bar Widget**: Minimalist white icon in the top bar with instant status.
- ⌨️ **Global Shortcut**: Bound to <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>T</kbd> to toggle the tasks panel instantly from any workspace.
- 📅 **Integrated Calendar Picker**: Select, modify, or remove task due dates using an interactive calendar popover with month navigation and quick presets (*Today*, *Tomorrow*, *+7 Days*).
- ⚡ **Optimistic & Responsive**: Immediate local updates on add, check, and due date changes with automatic background sync to Google Cloud.
- 🤖 **Model Context Protocol (MCP)**: Runs as a full stdio MCP server (`google_tasks_list`, `google_tasks_add`, `google_tasks_update`, `google_tasks_toggle`, `google_tasks_delete`), giving AI coding agents direct access to your task backlog.
- 🔒 **Zero Hardcoded Secrets**: Secure OAuth 2.0 loopback authentication stored in `~/.config/omarchy/google-tasks/`.

---

## 🚀 Installation

### Option 1: Quick Install Script

Clone the repository and run the installer:

```bash
git clone https://github.com/bmclain25/omarchy-plugin-tasks.git
cd omarchy-plugin-tasks
chmod +x install.sh
./install.sh
```

The script will:
1. Install plugin files to `~/.config/omarchy/plugins/bmclain.google-tasks/`.
2. Prompt for your Google Client ID and Secret (or you can provide them later).
3. Bind <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>T</kbd> in `~/.config/hypr/bindings.lua`.
4. Enable the widget in `~/.config/omarchy/shell.json` and reload the shell.
5. Register the Google Tasks MCP server in `~/.gemini/config/mcp_config.json`.

### Option 2: Omarchy Plugin Manager

```bash
omarchy plugin add https://github.com/bmclain25/omarchy-plugin-tasks.git --enable
```

---

## 🔑 Setting Up Google OAuth

To connect to your Google account, you need a Google Cloud OAuth 2.0 Client ID:

1. Open the [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Enable the **Google Tasks API** under **APIs & Services > Library**.
4. In **OAuth consent screen**:
   - Set user type to **External**.
   - Add your Google account as a Test User.
5. In **Credentials > Create Credentials > OAuth client ID**:
   - Application type: **Desktop app**.
   - Name: `Omarchy Google Tasks`.
6. Copy your **Client ID** and **Client Secret**, then save them to `~/.config/omarchy/google-tasks/credentials.json`:

```json
{
  "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
  "client_secret": "YOUR_CLIENT_SECRET"
}
```

Or configure via CLI:
```bash
~/.config/omarchy/plugins/bmclain.google-tasks/bin/tasks-cli setup
```

Once credentials are set, open the panel (<kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>T</kbd>) and click **"Sign In with Google"** to authorize in your browser.

---

## 🛠️ CLI & MCP Usage

The backend CLI is located at `~/.config/omarchy/plugins/bmclain.google-tasks/bin/tasks-cli`:

```bash
# Check status
tasks-cli status

# List tasks
tasks-cli list
tasks-cli list --refresh

# Add a task
tasks-cli add --title "Buy groceries" --due "2026-10-15"

# Toggle completion
tasks-cli toggle --id <task_id>

# Run MCP server over stdio
tasks-cli mcp
```

---

## 🗑️ Uninstallation

To cleanly remove the plugin:

```bash
./uninstall.sh
```

---

## 📄 License

MIT © 2026 [bmclain25](https://github.com/bmclain25)
