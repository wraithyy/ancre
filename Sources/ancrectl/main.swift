// ancrectl — CLI for the ancre control socket.
// Usage: ancrectl <command...>   e.g. `ancrectl workspace 3`,
//        `ancrectl layout scroll`, `ancrectl state`

import Foundation

let request = CommandLine.arguments.dropFirst().joined(separator: " ")
guard !request.isEmpty else {
    FileHandle.standardError.write(Data("usage: ancrectl <command...> | state\n".utf8))
    exit(2)
}

let path = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/ancre/ancre.sock").path
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { perror("socket"); exit(1) }
var timeout = timeval(tv_sec: 5, tv_usec: 0)
setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
_ = path.withCString { src in
    withUnsafeMutablePointer(to: &addr.sun_path) { dst in
        dst.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: addr.sun_path)) {
            strcpy($0, src)
        }
    }
}
let connected = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}
guard connected == 0 else {
    FileHandle.standardError.write(Data("ancrectl: cannot connect to \(path) — is ancre running?\n".utf8))
    exit(1)
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
close(fd)

let text = String(data: response, encoding: .utf8) ?? ""
print(text.trimmingCharacters(in: .newlines))
exit(text.hasPrefix("error") ? 1 : 0)
