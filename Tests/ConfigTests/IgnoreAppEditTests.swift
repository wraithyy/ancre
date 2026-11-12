import XCTest
@testable import Config
import TOMLKit

final class IgnoreAppEditTests: XCTestCase {
    private struct Doc: Decodable {
        struct General: Decodable {
            let ignoreApps: [String]
            enum CodingKeys: String, CodingKey { case ignoreApps = "ignore-apps" }
        }
        let general: General
    }

    private func ignored(after toml: String) throws -> [String] {
        let edited = ConfigLoader.addingIgnoredApp("com.example.game", to: toml)
        return try TOMLDecoder().decode(Doc.self, from: edited).general.ignoreApps
    }

    func testMultilineArrayKeepsCommentsAndItems() throws {
        let toml = """
        [general]
        # keep me
        ignore-apps = [  # trailing comment
          "com.apple.dt.Xcode",   # why
          "com.apple.ActivityMonitor"
        ]
        """
        XCTAssertEqual(try ignored(after: toml), ["com.example.game", "com.apple.dt.Xcode", "com.apple.ActivityMonitor"])
        XCTAssertTrue(ConfigLoader.addingIgnoredApp("x", to: toml).contains("# keep me"))
    }

    func testSingleLineArray() throws {
        XCTAssertEqual(try ignored(after: "[general]\nignore-apps = [\"a\"]  # c\n"), ["com.example.game", "a"])
    }

    func testEmptyArray() throws {
        XCTAssertEqual(try ignored(after: "[general]\nignore-apps = []\n"), ["com.example.game"])
    }

    func testMissingKeyGoesUnderGeneral() throws {
        XCTAssertEqual(try ignored(after: "[general]\ngaps-inner = 8\n[bar]\nenabled = true\n"), ["com.example.game"])
    }

    func testMissingGeneralSection() throws {
        XCTAssertEqual(try ignored(after: "[bar]\nenabled = true\n"), ["com.example.game"])
    }
}
