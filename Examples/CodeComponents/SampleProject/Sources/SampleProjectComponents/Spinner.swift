import simd
import UntoldComponentKit
import UntoldEngine

/// Spins its entity while the scene is playing.
///
/// Add it to an entity from the editor's Inspector and press Play. Change `speed` here
/// and save: with "Rebuild on save" on, the editor picks the change up without restarting.
final class Spinner: CodeComponent {
    @UntoldAttribute("Degrees per second", range: -360 ... 360) var speed: Float = 90
    @UntoldAttribute var axis: SIMD3<Float> = [0, 1, 0]

    override func onUpdate(deltaTime: Float) {
        guard simd_length(axis) > 0 else { return }
        rotateBy(entityId: entity, angle: speed * deltaTime, axis: simd_normalize(axis))
    }
}
