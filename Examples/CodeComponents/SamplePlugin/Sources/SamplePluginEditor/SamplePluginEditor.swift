import SamplePlugin
import UntoldComponentKit

/// The plugin's editor side. It arrives with the plugin: the editor compiles this folder when a
/// project lists the plugin in UntoldEditor.json, and these items appear in its menu bar.
final class SamplePluginEditor: EditorMenuPlugin {
    @UntoldMenu(.debug, "Sample Plugin/Fast Pulse", tooltip: "Four times the default pulse frequency.")
    var fastPulse = false

    @UntoldMenu(.tools, "Sample Plugin/Reset Pulse Clock")
    var resetClock = UntoldMenuAction { (owner: EditorMenuPlugin) in
        (owner as? SamplePluginEditor)?.fastPulse = false
        PulseClock.shared.reset()
    }

    override func menuDidChange(_: UntoldMenuDomain, _: String) {
        PulseClock.shared.frequency = fastPulse ? PulseClock.defaultFrequency * 4 : PulseClock.defaultFrequency
    }

    override func onUnload() {
        PulseClock.shared.reset()
    }
}
