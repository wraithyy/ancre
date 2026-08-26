// ancrectl — CLI for the ancre control socket.
// Usage: ancrectl <command...>   e.g. `ancrectl workspace 3`,
//        `ancrectl layout scroll`, `ancrectl state`
//        `ancrectl mcp` runs a built-in MCP stdio server (for
//        `claude mcp add ancre -- ancrectl mcp`) — no Node required.

import Foundation

/// One request line -> one response over the ancre unix socket.
func sendToAncre(_ request: String) -> Result<String, String> {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ancre/ancre.sock").path
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return .failure("socket() failed") }
    defer { close(fd) }
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: addr.sun_path)
    guard path.utf8.count < capacity else { return .failure("socket path too long") }
    path.withCString { src in
        withUnsafeMutablePointer(to: &addr.sun_path) { dst in
            _ = dst.withMemoryRebound(to: CChar.self, capacity: capacity) { strcpy($0, src) }
        }
    }
    let connected = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard connected == 0 else {
        return .failure("cannot connect to \(path) — is ancre running?")
    }

    let payload = request + "\n"
    _ = payload.withCString { write(fd, $0, strlen($0)) }

    var response = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = read(fd, &chunk, chunk.count)
        guard n > 0 else { break }
        response.append(contentsOf: chunk[0..<n])
    }
    return .success((String(data: response, encoding: .utf8) ?? "").trimmingCharacters(in: .newlines))
}

extension String: @retroactive Error {}

let arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty else {
    FileHandle.standardError.write(Data("usage: ancrectl <command...> | state | subscribe | mcp\n".utf8))
    exit(2)
}

if arguments == ["mcp"] {
    runMCPServer()
    exit(0)
}

switch sendToAncre(arguments.joined(separator: " ")) {
case .success(let text):
    print(text)
    exit(text.hasPrefix("error") ? 1 : 0)
case .failure(let message):
    FileHandle.standardError.write(Data("ancrectl: \(message)\n".utf8))
    exit(1)
}
