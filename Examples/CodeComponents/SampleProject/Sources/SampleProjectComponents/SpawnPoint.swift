import simd
import UntoldComponentKit
import UntoldEngine

// A kind of entity that the editor shows and the game does not.
//
// A spawn point is a position and a few settings. There is nothing to render, but without a
// marker nobody could find it in the viewport. So the component asks the editor for an icon,
// the way the editor marks its own lights. The icon is never saved and never reaches the game:
// there, a spawn point is only what `SpawnPoint.all(for:)` returns.

/// The "Spawn Point" row on the Entities shelf.
final class SpawnPointEntity: EntityTemplate {
    override class var systemImage: String {
        "flag"
    }

    override func build(_ entity: EntityID) {
        add(SpawnPoint.self, to: entity)
    }
}

final class SpawnPoint: CodeComponent {
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

    /// Read by the editor while editing, so the flag takes the team's color as soon as the
    /// team changes in the Inspector.
    override var editorRepresentation: EditorRepresentation {
        .icon(systemImage: "flag.fill", tint: team.tint)
    }

    /// What the game asks for: where the players of a team may appear.
    static func all(for team: Team) -> [SIMD3<Float>] {
        CodeComponentRegistry.entities(with: SpawnPoint.self)
            .compactMap { CodeComponentRegistry.component(SpawnPoint.self, on: $0) }
            .filter { $0.team == team }
            .compactMap { $0.transform?.position }
    }
}
