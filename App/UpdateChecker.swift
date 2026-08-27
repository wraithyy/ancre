// Once-a-day update check against GitHub Releases. Notification only — a
// menubar menu item pointing at the release page; never downloads anything.
// In-place autoupdate (Sparkle) is deliberately out until the app has a
// Developer ID signature: replacing an ad-hoc signed bundle can drop the
// Accessibility/Input Monitoring grant, silently breaking the WM.

import Foundation

enum UpdateChecker {
    static let releasesURL = URL(string: "https://github.com/wraithyy/ancre/releases/latest")!
    private static let api = URL(string: "https://api.github.com/repos/wraithyy/ancre/releases/latest")!

    /// Calls back on the main queue with the newer version ("0.2.0"), or not
    /// at all (offline, rate-limited, up to date, dev build without a bundle).
    static func check(onUpdate: @escaping (String) -> Void) {
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard isNewer(latest, than: current) else { return }
            DispatchQueue.main.async { onUpdate(latest) }
        }.resume()
    }

    /// Numeric dot-component compare; missing components count as 0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        let b = current.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
