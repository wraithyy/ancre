import XCTest
@testable import Config
import TOMLKit

final class ConfigDecodingTests: XCTestCase {
    /// Old config copied before newer keys existed must still decode with defaults.
    func testMinimalConfigGetsDefaults() throws {
        let toml = """
        [general]
        gaps-inner = 8
        gaps-outer = 8
        animations = true
        animation-duration-ms = 180
        default-layout = "dwindle"
        [hyper]
        key = "caps_lock"
        [keybindings]
        [bar]
        enabled = true
        position = "top"
        """
        let config = try TOMLDecoder().decode(AppConfig.self, from: toml)
        XCTAssertEqual(config.bar.opacity, 1.0, "native .bar material default")
        XCTAssertEqual(config.bar.height, 28)
        XCTAssertEqual(config.bar.align, "center")
        XCTAssertEqual(config.bar.iconSize, 17)
        XCTAssertNil(config.theme)
        XCTAssertNil(config.border)
        XCTAssertNil(config.workspaceLabels)
        // Integer gaps must decode into Double fields.
        XCTAssertEqual(config.general.gapsInner, 8)
        // Configs without the app-rule keys default to empty lists.
        XCTAssertEqual(config.general.ignoreApps, [])
        XCTAssertEqual(config.general.floatApps, [])
    }

    func testAppRulesDecode() throws {
        let toml = """
        [general]
        ignore-apps = ["com.apple.dt.Xcode"]
        float-apps = ["com.apple.systempreferences"]
        [hyper]
        key = "caps_lock"
        [keybindings]
        [bar]
        enabled = true
        position = "top"
        """
        let config = try TOMLDecoder().decode(AppConfig.self, from: toml)
        XCTAssertEqual(config.general.ignoreApps, ["com.apple.dt.Xcode"])
        XCTAssertEqual(config.general.floatApps, ["com.apple.systempreferences"])
    }

    func testFullThemingDecodes() throws {
        let toml = """
        [general]
        gaps-inner = 8.0
        gaps-outer = 8.0
        animations = true
        animation-duration-ms = 180
        default-layout = "dwindle"
        [hyper]
        key = "caps_lock"
        [keybindings]
        [bar]
        enabled = true
        position = "bottom"
        align = "right"
        offset-x = 12
        offset-y = 4
        icon-size = 20
        background-color = "#1e1e2eCC"
        [theme]
        accent = "#89b4fa"
        [border]
        enabled = false
        width = 3
        [workspace-labels]
        "1" = { icon = "X", name = "web", show-number = false, hide-when-empty = true }
        [app-workspaces]
        "com.spotify.client" = "9"
        """
        let config = try TOMLDecoder().decode(AppConfig.self, from: toml)
        XCTAssertEqual(config.bar.align, "right")
        XCTAssertEqual(config.bar.offsetX, 12)
        XCTAssertEqual(config.bar.offsetY, 4)
        XCTAssertEqual(config.bar.iconSize, 20)
        XCTAssertEqual(config.bar.backgroundColor, "#1e1e2eCC")
        XCTAssertEqual(config.theme?.accent, "#89b4fa")
        XCTAssertEqual(config.border?.enabled, false)
        XCTAssertEqual(config.border?.width, 3)
        XCTAssertEqual(config.border?.radius, 10, "missing key gets default (system corner radius)")
        let label = try XCTUnwrap(config.workspaceLabels?["1"])
        XCTAssertEqual(label.name, "web")
        XCTAssertFalse(label.showNumber)
        XCTAssertTrue(label.hideWhenEmpty)
        XCTAssertEqual(config.appWorkspaces?["com.spotify.client"], "9")
    }

    /// The bundled default.toml must always decode — a bad default is a fatalError at startup.
    func testBundledDefaultDecodes() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // ConfigTests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // repo root
            .appendingPathComponent("Sources/Config/default.toml")
        _ = try TOMLDecoder().decode(AppConfig.self, from: String(contentsOf: url, encoding: .utf8))
    }

    /// A config missing the formerly-required structural keys must still decode
    /// with defaults instead of throwing and discarding the whole user config.
    func testConfigWithoutStructuralKeysDecodes() throws {
        let toml = """
        [general]
        gaps-inner = 12
        [hyper]
        key = "caps_lock"
        [keybindings]
        [bar]
        height = 32
        """
        let config = try TOMLDecoder().decode(AppConfig.self, from: toml)
        XCTAssertEqual(config.general.animations, true)
        XCTAssertEqual(config.general.animationDurationMs, 180)
        XCTAssertEqual(config.general.defaultLayout, "dwindle")
        XCTAssertEqual(config.bar.enabled, true)
        XCTAssertEqual(config.bar.position, "top")
        XCTAssertEqual(config.general.gapsInner, 12, "user values survive")
        XCTAssertEqual(config.bar.height, 32, "user values survive")
    }

}
