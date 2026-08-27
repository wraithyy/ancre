// InputSystem — facade wiring the hidutil remap and the CGEventTap together.
// Decoupled from WMCore: callers pass a plain (String) -> Bool handler that
// resolves binding identifiers ("hyper-shift-h") to actions themselves.

import Foundation

public final class InputSystem {
    public typealias Handler = (String) -> Bool

    private var remap: HidutilRemap?
    private var tapManager: EventTapManager?

    public init() {}

    /// Starts the remap + event tap. `hyperKeyName` matches the `[hyper].key`
    /// config value ("caps_lock", "f13".."f20", "right_cmd", "right_option").
    /// `onHyperStateChange` fires on the tap thread when the hyper key goes
    /// down/up — receivers must only dispatch async.
    public func start(
        hyperKeyName: String,
        handler: @escaping Handler,
        onHyperMouse: ((HyperMouseButton, HyperMousePhase, CGPoint) -> Void)? = nil,
        onObservedMouseUp: ((HyperMouseButton, CGPoint) -> Void)? = nil,
        onHyperStateChange: ((Bool) -> Void)? = nil,
        onTapDisabled: (() -> Void)? = nil,
        onRemapFailure: ((String) -> Void)? = nil
    ) {
        let remap = HidutilRemap(srcName: hyperKeyName, dstName: "f18")
        remap.onApplyFailure = onRemapFailure
        remap.apply()
        self.remap = remap
        InputSystem.installQuitSignalHandlers()
        InputSystem.activeRemapForSignalHandler = remap

        let tapManager = EventTapManager(handler: handler)
        tapManager.onHyperStateChange = onHyperStateChange
        tapManager.onHyperMouse = onHyperMouse
        tapManager.onObservedMouseUp = onObservedMouseUp
        tapManager.onTapDisabled = onTapDisabled
        tapManager.start()
        self.tapManager = tapManager
    }

    /// Regions (CG top-left) where hyper+clicks pass through — the WM's own
    /// clickable overlays (bar). Thread-safe.
    public func setPassThroughRegions(_ regions: [CGRect]) {
        tapManager?.setPassThroughRegions(regions)
    }

    public func stop() {
        tapManager?.stop()
        tapManager = nil
        remap?.revert()
        remap = nil
        InputSystem.activeRemapForSignalHandler = nil
    }

    // Best-effort revert on SIGTERM/SIGINT so a killed process doesn't leave
    // CapsLock stuck as F18. Raw signal handlers may only call
    // async-signal-safe functions (Process/ARC are not), so delivery goes
    // through DispatchSourceSignal on a normal queue instead.
    private static var activeRemapForSignalHandler: HidutilRemap? {
        didSet { _ = oldValue } // silence unused-value warnings under -O
    }
    private static var installedSignalHandlers = false
    private static var signalSources: [DispatchSourceSignal] = []

    private static func installQuitSignalHandlers() {
        guard !installedSignalHandlers else { return }
        installedSignalHandlers = true
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN) // let dispatch own delivery
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .global())
            source.setEventHandler {
                InputSystem.revertRemapFromSignal()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private static func revertRemapFromSignal() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", "{\"UserKeyMapping\":[]}"]
        try? process.run()
        process.waitUntilExit()
    }
}
