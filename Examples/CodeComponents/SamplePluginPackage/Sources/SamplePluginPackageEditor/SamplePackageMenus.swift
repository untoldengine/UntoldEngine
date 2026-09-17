import SamplePluginPackage
import UntoldComponentKit

/// The package's editor side: an EditorMenuPlugin. It arrives with the package. The editor
/// compiles this folder when a project lists the package in UntoldEditor.json, and these
/// items appear in its menu bar. No game target compiles it.
final class SamplePackageMenus: EditorMenuPlugin {
    @UntoldMenu(.debug, "Sample Package/Fast Pulse", tooltip: "Four times the default pulse frequency.")
    var fastPulse = false

    @UntoldMenu(.tools, "Sample Package/Reset Pulse Clock")
    var resetClock = UntoldMenuAction { (owner: EditorMenuPlugin) in
        (owner as? SamplePackageMenus)?.fastPulse = false
        PulseClock.shared.reset()
    }

    override func menuDidChange(_: UntoldMenuDomain, _: String) {
        PulseClock.shared.frequency = fastPulse ? PulseClock.defaultFrequency * 4 : PulseClock.defaultFrequency
    }

    override func onUnload() {
        PulseClock.shared.reset()
    }
}
