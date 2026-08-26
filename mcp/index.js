#!/usr/bin/env node
// MCP server for applland — a thin wrapper over the control socket
// (/tmp/applland-$UID.sock). Requests are single lines; applland validates
// everything through its strict command grammar.

import { createConnection } from "node:net";
import { homedir } from "node:os";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const SOCKET = `${homedir()}/Library/Application Support/applland/applland.sock`;

function send(request) {
  return new Promise((resolve, reject) => {
    const socket = createConnection(SOCKET);
    let data = "";
    socket.setTimeout(3000, () => {
      socket.destroy();
      reject(new Error("applland socket timeout"));
    });
    socket.on("connect", () => socket.write(request + "\n"));
    socket.on("data", (chunk) => (data += chunk));
    socket.on("end", () => resolve(data.trim()));
    socket.on("error", (err) =>
      reject(new Error(`cannot reach applland at ${SOCKET} (${err.code}) — is it running?`))
    );
  });
}

const asText = (text) => ({ content: [{ type: "text", text }] });

const server = new McpServer({ name: "applland", version: "0.1.0" });

server.tool(
  "applland_state",
  "Current window-manager state as JSON: monitors (stable ids), their workspaces (name, layout, active), and windows (id, pid, bundleID, title, floating, focused). Window ids from here are the handles for the other tools.",
  {},
  async () => asText(await send("state"))
);

server.tool(
  "applland_command",
  "Dispatch a window-manager command, same grammar as keybindings: 'workspace <name>', 'move-to-workspace <name>' (focused window), 'focus left|down|up|right', 'move left|down|up|right', 'resize width|height <delta>', 'layout dwindle|scroll|<custom>', 'toggle-floating', 'toggle-fullscreen', 'focus-monitor next|previous', 'adopt-window', 'pause-tiling', 'retile', 'open-config'. Returns 'ok' or 'error: ...'.",
  { command: z.string().describe("command string, e.g. 'workspace 3'") },
  async ({ command }) => asText(await send(command))
);

server.tool(
  "applland_move_window",
  "Move a specific window (id from applland_state) to a workspace.",
  {
    window_id: z.number().int().describe("window id from applland_state"),
    workspace: z.string().describe("target workspace name, e.g. '3'"),
  },
  async ({ window_id, workspace }) => asText(await send(`move-window ${window_id} ${workspace}`))
);

server.tool(
  "applland_focus_window",
  "Focus a specific window (switches to its workspace first).",
  { window_id: z.number().int() },
  async ({ window_id }) => asText(await send(`focus-window ${window_id}`))
);

server.tool(
  "applland_set_floating",
  "Float (true) or tile (false) a specific window.",
  { window_id: z.number().int(), floating: z.boolean() },
  async ({ window_id, floating }) => asText(await send(`set-floating ${window_id} ${floating}`))
);

await server.connect(new StdioServerTransport());
