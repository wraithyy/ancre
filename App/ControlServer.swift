// IPC for appllandctl / MCP (Task 7.1): a unix domain socket accepting one
// line-based request per connection and replying with one line.
//
// Security model: the socket lives in a per-UID path with 0600 permissions —
// filesystem permissions are the auth boundary (any process running as the
// user could drive the AX API directly anyway; the socket adds no privilege).
// No network exposure, requests are parsed by the strict Command grammar
// (never a shell), and oversized requests drop the connection.

import Foundation

final class ControlServer {
    /// Handles one request line; must call the reply exactly once (any thread).
    typealias Handler = (String, @escaping (String) -> Void) -> Void

    /// Lives in the user's own Application Support (0700 dir), not /tmp —
    /// a shared /tmp lets another local user pre-squat the predictable path
    /// (bind DoS) or spoof the server for our clients.
    static var socketPath: String {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/applland")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return dir.appendingPathComponent("applland.sock").path
    }

    private let handler: Handler
    private let queue = DispatchQueue(label: "com.applland.control")
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    /// Max request size; anything longer is a misbehaving client.
    private let maxRequestBytes = 4096
    /// Clients that sent "subscribe" — they keep their fd and receive
    /// broadcast event lines until they disconnect.
    private var subscribers: [Int32] = []

    init?(handler: @escaping Handler) {
        self.handler = handler
        let path = Self.socketPath
        unlink(path)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else { return nil }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard path.utf8.count < capacity else { close(listenFD); return nil }
        path.withCString { src in
            withUnsafeMutablePointer(to: &addr.sun_path) { dst in
                _ = dst.withMemoryRebound(to: CChar.self, capacity: capacity) { strcpy($0, src) }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0, listen(listenFD, 8) == 0, chmod(path, 0o600) == 0 else {
            close(listenFD)
            unlink(path)
            NSLog("applland: control socket setup failed at %@", path)
            return nil
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: listenFD, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnection() }
        source.resume()
        acceptSource = source
        NSLog("applland: control socket at %@", path)
    }

    deinit {
        acceptSource?.cancel()
        if listenFD >= 0 { close(listenFD) }
        unlink(Self.socketPath)
    }

    private func acceptConnection() {
        let fd = accept(listenFD, nil, nil)
        guard fd >= 0 else { return }
        // A client that connects and never writes must not wedge the IPC:
        // bound the read with a timeout and do it off the accept queue.
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        // A subscriber that vanished must not SIGPIPE the whole app on write.
        var noSigpipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, socklen_t(MemoryLayout<Int32>.size))
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { close(fd); return }
            var buffer = Data()
            var chunk = [UInt8](repeating: 0, count: 1024)
            while buffer.count < self.maxRequestBytes, !buffer.contains(0x0A) {
                let n = read(fd, &chunk, chunk.count)
                guard n > 0 else { break }
                buffer.append(contentsOf: chunk[0..<n])
            }
            guard let line = String(data: buffer, encoding: .utf8)?
                .split(separator: "\n", maxSplits: 1).first
                .map(String.init)?
                .trimmingCharacters(in: .whitespaces),
                !line.isEmpty, buffer.count <= self.maxRequestBytes
            else {
                close(fd)
                return
            }
            if line == "subscribe" {
                self.queue.async {
                    var data = Data("subscribed\n".utf8)
                    data.withUnsafeBytes { _ = write(fd, $0.baseAddress, $0.count) }
                    self.subscribers.append(fd)
                }
                return
            }
            self.handler(line) { response in
                self.queue.async {
                    var data = Data(response.utf8)
                    data.append(0x0A)
                    data.withUnsafeBytes { _ = write(fd, $0.baseAddress, $0.count) }
                    close(fd)
                }
            }
        }
    }

    /// Pushes one event line to every subscriber; dead connections are
    /// dropped. Safe from any thread.
    func broadcast(_ line: String) {
        queue.async { [weak self] in
            guard let self, !self.subscribers.isEmpty else { return }
            var data = Data(line.utf8)
            data.append(0x0A)
            self.subscribers.removeAll { fd in
                let written = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
                if written <= 0 {
                    close(fd)
                    return true
                }
                return false
            }
        }
    }
}
