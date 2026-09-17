import SamplePlugin
import simd
import UntoldComponentKit
import UntoldEngine

/// Moves its entity up and down, in step with the sample plugin's shared clock, so every Bobber
/// in the scene moves together.
///
/// It imports a plugin module. In the game that is an ordinary package dependency; in the editor
/// the plugin is compiled and loaded first, and this file is compiled against it.
final class Bobber: ComponentPlugin {
    @UntoldAttribute("Height", range: 0 ... 3, step: 0.05) var height: Float = 0.5
    @UntoldAttribute var startsFromCurrentPosition = true
    @UntoldAttribute var anchor: SIMD3<Float> = .zero

    private var time: Float = 0

    override class var actions: [PluginAction] {
        [PluginAction("Anchor Here") { ($0 as? Bobber)?.anchorAtCurrentPosition() }]
    }

    override func onStart() {
        time = 0
        if startsFromCurrentPosition {
            anchorAtCurrentPosition()
        }
    }

    override func onUpdate(deltaTime: Float) {
        time += deltaTime
        let offset = PulseClock.shared.wave(at: time) * height
        translateTo(entityId: entity, position: anchor + SIMD3<Float>(0, offset, 0))
    }

    func anchorAtCurrentPosition() {
        if let transform {
            anchor = transform.position
        }
    }
}
