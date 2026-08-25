import CoreGraphics

/// Hidden-workspace windows are "parked" just past the bottom-right corner of
/// the desktop. macOS clamps AX positions so a sliver stays on screen — the
/// exact clamp behavior is version-dependent, which is why this lives in one
/// place: when a macOS update changes it, only this file needs patching.
public enum OffscreenParking {
    /// Park target for a window of `size`, where `bounds` is the union of all
    /// display frames in CG (top-left origin) coordinates. It has to be the
    /// union, not the window's own monitor: parking past one display's edge
    /// would drop the window onto the neighbouring display.
    public static func parkFrame(size: CGSize, bounds: CGRect) -> AXFrame {
        AXFrame(
            origin: CGPoint(x: bounds.maxX - 1, y: bounds.maxY - 1),
            size: size
        )
    }

    /// A window counts as parked if its visible portion is a corner sliver
    /// (position was clamped, exact origin unknown).
    public static func isParked(_ frame: AXFrame, bounds: CGRect) -> Bool {
        frame.origin.x > bounds.maxX - frame.size.width - 2 &&
            frame.origin.y > bounds.maxY - frame.size.height - 2
    }
}
