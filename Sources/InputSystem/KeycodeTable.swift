// Virtual keycode <-> name mapping (US physical layout, Hyprland-style: keys
// are named by physical position, not by what a modifier shifts them to).

import Foundation

enum KeycodeTable {
    /// Virtual keycode -> lowercase name used in binding identifiers ("h", "1", "left"...).
    static let nameByKeycode: [Int64: String] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g", 4: "h",
        34: "i", 38: "j", 40: "k", 37: "l", 46: "m", 45: "n", 31: "o", 35: "p",
        12: "q", 15: "r", 1: "s", 17: "t", 32: "u", 9: "v", 13: "w", 7: "x",
        16: "y", 6: "z",

        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9",

        123: "left", 124: "right", 125: "down", 126: "up",

        36: "return", 48: "tab", 49: "space", 51: "delete", 53: "escape",
        18000: "unused", // placeholder guard, never emitted

        27: "minus", 24: "equal", 33: "leftbracket", 30: "rightbracket",
        42: "backslash", 41: "semicolon", 39: "quote", 43: "comma",
        47: "period", 44: "slash", 50: "grave",

        // F13..F20 (used by hidutil remaps; F18 is the default hyper carrier).
        105: "f13", 107: "f14", 113: "f15", 106: "f16", 64: "f17", 79: "f18",
        80: "f19", 90: "f20",
    ]

    static func name(forKeycode keycode: Int64) -> String? {
        nameByKeycode[keycode]
    }
}
