// Built-in MCP server (stdio transport, newline-delimited JSON-RPC) — a thin
// wrapper over the ancre control socket, so Homebrew users register the MCP
// with `claude mcp add ancre -- ancrectl mcp` and need no Node/repo checkout.

import Foundation

private let toolDefinitions: [[String: Any]] = [
    [
        "name": "ancre_state",
        "description": "Current window-manager state as JSON: monitors (stable ids), workspaces (name, layout, active) and windows (id, pid, bundleID, title, floating, focused). Window ids are the handles for the other tools.",
        "inputSchema": ["type": "object", "properties": [:] as [String: Any]],
    ],
    [
        "name": "ancre_command",
        "description": "Dispatch a window-manager command, same grammar as keybindings: 'workspace <name>', 'move-to-workspace <name>', 'focus left|down|up|right', 'move left|down|up|right', 'resize width|height <delta>', 'layout dwindle|scroll|stack|<custom>', 'toggle-floating', 'toggle-fullscreen', 'focus-monitor next|previous', 'adopt-window', 'pause-tiling', 'retile', 'preset <name>', 'preset-save <name>', 'reload-config'. Returns 'ok' or 'error: ...'.",
        "inputSchema": [
            "type": "object",
            "properties": ["command": ["type": "string", "description": "command string, e.g. 'workspace 3'"]],
            "required": ["command"],
        ],
    ],
    [
        "name": "ancre_arrange",
        "description": "Apply a whole declarative setup in ONE call: per-workspace layouts, app-to-workspace placement (all windows of a bundle id), specific window placement (finer than apps), which workspaces to activate, and the window to focus at the end. Prefer this over many single calls.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "layouts": ["type": "object", "description": "workspace name -> layout name"],
                "apps": ["type": "object", "description": "bundle id -> workspace name"],
                "windows": ["type": "object", "description": "window id (string, from ancre_state) -> workspace name"],
                "active": ["type": "array", "items": ["type": "string"], "description": "workspaces to activate"],
                "focus": ["type": "integer", "description": "window id to focus at the end"],
            ],
        ],
    ],
    [
        "name": "ancre_move_window",
        "description": "Move a specific window (id from ancre_state) to a workspace.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "window_id": ["type": "integer"],
                "workspace": ["type": "string"],
            ],
            "required": ["window_id", "workspace"],
        ],
    ],
    [
        "name": "ancre_focus_window",
        "description": "Focus a specific window (switches to its workspace first).",
        "inputSchema": [
            "type": "object",
            "properties": ["window_id": ["type": "integer"]],
            "required": ["window_id"],
        ],
    ],
    [
        "name": "ancre_move_log",
        "description": "Summary of the user's manual window moves (from ~/Library/Application Support/ancre/move-log.jsonl, written by the app when general.move-log is on). Returns per-app destination histograms: {days, totalMoves, apps: [{bundleID, moves, destinations, topWorkspace, topShare}]}. Purpose: suggest [app-workspaces] rules for ~/.config/ancre/ancre.toml — an app with moves >= 3 and topShare >= 0.8 is a candidate rule 'bundleID = \"workspace\"'. Before suggesting, read the config to skip apps that already have a rule; after editing, apply with the 'reload-config' command.",
        "inputSchema": [
            "type": "object",
            "properties": ["days": ["type": "integer", "description": "look-back window in days (default 30)"]],
        ],
    ],
    [
        "name": "ancre_set_floating",
        "description": "Float (true) or tile (false) a specific window.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "window_id": ["type": "integer"],
                "floating": ["type": "boolean"],
            ],
            "required": ["window_id", "floating"],
        ],
    ],
]

/// Aggregates the move log locally — no socket, works with the app not running.
private func moveLogSummary(days: Int) -> String {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ancre/move-log.jsonl")
    let cutoff = Int(Date().timeIntervalSince1970) - days * 86_400
    var perApp: [String: [String: Int]] = [:] // bundleID -> destination workspace -> count
    if let content = try? String(contentsOf: url, encoding: .utf8) {
        for line in content.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let ts = record["ts"] as? Int, ts >= cutoff,
                  let bundleID = record["bundleID"] as? String,
                  let to = record["to"] as? String else { continue }
            perApp[bundleID, default: [:]][to, default: 0] += 1
        }
    }
    let apps: [[String: Any]] = perApp.map { bundleID, destinations in
        let total = destinations.values.reduce(0, +)
        let top = destinations.max { $0.value < $1.value }!
        return [
            "bundleID": bundleID,
            "moves": total,
            "destinations": destinations,
            "topWorkspace": top.key,
            "topShare": (Double(top.value) / Double(total) * 100).rounded() / 100,
        ]
    }.sorted { ($0["moves"] as! Int) > ($1["moves"] as! Int) }
    let summary: [String: Any] = [
        "days": days,
        "totalMoves": apps.reduce(0) { $0 + ($1["moves"] as! Int) },
        "apps": apps,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: summary),
          let json = String(data: data, encoding: .utf8) else { return "error: cannot serialize summary" }
    return json
}

/// Maps one MCP tool call onto a control-socket request line.
private func socketRequest(tool: String, arguments: [String: Any]) -> String? {
    switch tool {
    case "ancre_state":
        return "state"
    case "ancre_command":
        return arguments["command"] as? String
    case "ancre_arrange":
        var payload: [String: Any] = [:]
        if let layouts = arguments["layouts"] { payload["layouts"] = layouts }
        if let apps = arguments["apps"] { payload["apps"] = apps }
        if let windows = arguments["windows"] { payload["windows"] = windows }
        if let active = arguments["active"] { payload["active"] = active }
        if let focus = arguments["focus"] { payload["focus"] = focus }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return "arrange \(json)"
    case "ancre_move_window":
        guard let id = arguments["window_id"] as? Int, let workspace = arguments["workspace"] as? String else { return nil }
        return "move-window \(id) \(workspace)"
    case "ancre_focus_window":
        guard let id = arguments["window_id"] as? Int else { return nil }
        return "focus-window \(id)"
    case "ancre_set_floating":
        guard let id = arguments["window_id"] as? Int, let floating = arguments["floating"] as? Bool else { return nil }
        return "set-floating \(id) \(floating)"
    default:
        return nil
    }
}

private func emit(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

private func reply(id: Any, result: [String: Any]) {
    emit(["jsonrpc": "2.0", "id": id, "result": result])
}

private func replyError(id: Any, code: Int, message: String) {
    emit(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
}

/// Blocking stdio loop; returns on EOF (client closed the pipe).
func runMCPServer() {
    while let line = readLine(strippingNewline: true) {
        guard !line.isEmpty,
              let data = line.data(using: .utf8),
              let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
        let method = message["method"] as? String ?? ""
        let id = message["id"]

        // Notifications (no id) need no response.
        guard let id else { continue }

        switch method {
        case "initialize":
            let params = message["params"] as? [String: Any]
            let version = params?["protocolVersion"] as? String ?? "2024-11-05"
            reply(id: id, result: [
                "protocolVersion": version,
                "capabilities": ["tools": [:] as [String: Any]],
                "serverInfo": ["name": "ancre", "version": "1.0.0"],
            ])
        case "ping":
            reply(id: id, result: [:])
        case "tools/list":
            reply(id: id, result: ["tools": toolDefinitions])
        case "tools/call":
            let params = message["params"] as? [String: Any] ?? [:]
            let tool = params["name"] as? String ?? ""
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            if tool == "ancre_move_log" {
                let days = arguments["days"] as? Int ?? 30
                let text = moveLogSummary(days: days)
                reply(id: id, result: [
                    "content": [["type": "text", "text": text]],
                    "isError": text.hasPrefix("error"),
                ])
                continue
            }
            guard let request = socketRequest(tool: tool, arguments: arguments) else {
                replyError(id: id, code: -32602, message: "unknown tool or bad arguments: \(tool)")
                continue
            }
            switch sendToAncre(request) {
            case .success(let text):
                reply(id: id, result: [
                    "content": [["type": "text", "text": text]],
                    "isError": text.hasPrefix("error"),
                ])
            case .failure(let message):
                reply(id: id, result: [
                    "content": [["type": "text", "text": "error: \(message)"]],
                    "isError": true,
                ])
            }
        default:
            replyError(id: id, code: -32601, message: "method not supported: \(method)")
        }
    }
}
