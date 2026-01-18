# Penpot MCP Onboarding Guide

This guide helps you set up and use Penpot with Claude Code via MCP (Model Context Protocol).

## What is Penpot MCP?

Penpot MCP enables AI-assisted design workflows by connecting Penpot (open-source design tool) to Claude Code. This allows you to:

- Query and manipulate design elements programmatically
- Generate design components with AI assistance
- Export designs and assets
- Automate repetitive design tasks

## Prerequisites

- **Node.js v22+** (tested with v25.3.0)
- **Penpot account** at [design.penpot.app](https://design.penpot.app) or self-hosted instance
- **Claude Code CLI** installed

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/penpot/penpot-mcp.git
cd penpot-mcp
```

### 2. Install and Build

```bash
npm run bootstrap
```

This command:
- Installs all dependencies
- Builds all components
- Starts the MCP server (port 4401) and plugin server (port 4400)

### 3. Configure Claude Code

```bash
claude mcp add penpot -t http http://localhost:4401/mcp
```

Verify the connection:
```bash
claude mcp list
```

Expected output:
```
penpot: http://localhost:4401/mcp (HTTP) - ✓ Connected
```

## Connecting Penpot to MCP

### Step 1: Open Penpot

1. Go to [design.penpot.app](https://design.penpot.app)
2. Open an existing project or create a new one
3. Open a design file (you must be inside a design file, not just the project)

### Step 2: Load the Plugin

1. Click on the **Plugins** menu (puzzle piece icon in the toolbar)
2. Select **Load development plugin**
3. Enter: `http://localhost:4400/manifest.json`
4. Click **Load**

### Step 3: Connect to MCP Server

1. The plugin panel will appear
2. Click **"Connect to MCP server"**
3. Wait for status to change to **"Connected"**

**Important**: Keep the plugin panel open during your session. Closing it disconnects the MCP connection.

## Browser Compatibility

| Browser | Status |
|---------|--------|
| Firefox | Works without issues |
| Chrome/Chromium v142+ | May show permission prompts for localhost access |
| Brave | May require disabling shields |

If you see permission prompts, allow the connection to localhost.

## Usage with Claude Code

Once connected, start a new Claude Code session:

```bash
claude
```

You can now ask Claude to interact with your Penpot designs:

**Example prompts:**
- "List all components in my current Penpot file"
- "Create a button component with rounded corners"
- "Export the selected frame as PNG"
- "Change the background color of the selected element to blue"

## Server Endpoints

| Endpoint | URL | Purpose |
|----------|-----|---------|
| HTTP/MCP | `http://localhost:4401/mcp` | Claude Code connection |
| SSE | `http://localhost:4401/sse` | Claude Desktop connection |
| Plugin | `http://localhost:4400/manifest.json` | Penpot plugin manifest |
| WebSocket | `ws://localhost:4402` | Plugin-to-server communication |

## Environment Variables

Customize the server with these environment variables:

```bash
# Server settings
export PENPOT_MCP_SERVER_PORT=4401
export PENPOT_MCP_SERVER_LISTEN_ADDRESS=localhost

# Logging
export PENPOT_MCP_LOG_LEVEL=info  # trace/debug/info/warn/error
export PENPOT_MCP_LOG_DIR=logs

# Remote access (use with caution)
export PENPOT_MCP_REMOTE_MODE=true
export PENPOT_MCP_SERVER_ADDRESS=your-domain.com
```

## Troubleshooting

### MCP Server Not Connecting

1. Ensure the server is running:
   ```bash
   cd penpot-mcp
   npm run bootstrap
   ```

2. Check if port 4401 is in use:
   ```bash
   lsof -i :4401
   ```

3. Verify Claude Code configuration:
   ```bash
   claude mcp list
   ```

### Plugin Not Loading in Penpot

1. Ensure the plugin server is running (port 4400)
2. Check browser console for errors (F12 > Console)
3. Try Firefox if Chrome has permission issues

### Connection Drops

- Keep the plugin panel open in Penpot
- Don't navigate away from the design file
- Refresh the page and reconnect if needed

## Project Structure

```
penpot-mcp/
├── mcp-server/      # MCP server implementation
├── penpot-plugin/   # Penpot plugin code
├── common/          # Shared utilities
├── python-scripts/  # Additional tooling
└── docs/            # Documentation
```

## Quick Reference

| Task | Command |
|------|---------|
| Start servers | `cd penpot-mcp && npm run bootstrap` |
| Add to Claude Code | `claude mcp add penpot -t http http://localhost:4401/mcp` |
| Check connection | `claude mcp list` |
| Remove from Claude | `claude mcp remove penpot` |

## Resources

- [Penpot MCP GitHub](https://github.com/penpot/penpot-mcp)
- [Penpot Documentation](https://help.penpot.app/)
- [Penpot Community](https://community.penpot.app/)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)

---

*Last updated: January 2026*
