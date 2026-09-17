import Foundation
import simd
import UntoldComponentKit
import UntoldEngine

// A kind of entity that the editor shows and the game does not.
//
// A spawn point is a position and a few settings. There is nothing to render, but without a
// marker nobody could find it in the viewport, or see how far its radius reaches. So the entity
// has an editor representation and no geometry: a flag in the team's color and a circle for
// the radius. They are drawn while editing, never saved, and never reach the game. There, a
// spawn point is only what `SpawnPointEntity.all(for:)` returns.

/// The "Spawn Point" row on the editor's Entities shelf, and every spawn point made from it.
final class SpawnPointEntity: EntityPlugin {
    enum Team: String, CaseIterable {
        case neutral, red, blue

        var tint: SIMD3<Float> {
            switch self {
            case .neutral: SIMD3<Float>(0.85, 0.85, 0.85)
            case .red: SIMD3<Float>(0.95, 0.35, 0.30)
            case .blue: SIMD3<Float>(0.35, 0.60, 1.00)
            }
        }
    }

    @UntoldAttribute var team: Team = .neutral
    @UntoldAttribute("Spawn Radius", range: 0 ... 10, step: 0.1) var radius: Float = 1

    override class var systemImage: String {
        "flag"
    }

    /// Read by the editor while editing, so the flag takes the team's color and the circle
    /// takes the radius as soon as they change in the Inspector.
    override var editorRepresentation: EditorRepresentation {
        var items: [EditorRepresentation.Item] = [.icon(systemImage: "flag.fill", tint: team.tint)]
        if radius > 0 {
            let circle = (0 ..< 48).map { index -> SIMD3<Float> in
                let angle = Float(index) / 48 * 2 * .pi
                return SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
            }
            items.append(.polyline(circle, closed: true))
        }
        return EditorRepresentation(items)
    }

    /// What the game asks for: where the players of a team may appear.
    static func all(for team: Team) -> [SIMD3<Float>] {
        EntityPluginRegistry.entities(of: SpawnPointEntity.self)
            .compactMap { EntityPluginRegistry.plugin(SpawnPointEntity.self, on: $0) }
            .filter { $0.team == team }
            .compactMap { $0.transform?.position }
    }
}
