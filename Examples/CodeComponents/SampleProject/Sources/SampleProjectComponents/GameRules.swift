import UntoldComponentKit
import UntoldEngine

// A kind of entity with nothing to show at all, in the editor or in the game.
//
// The rules of a match are data and behaviour. They live on an entity so the scene saves them
// and the Inspector edits them, and that entity never needs a shape or a marker: it is found
// by name in the hierarchy. The template is what makes it one double-click to create.

/// The "Game Rules" row on the Entities shelf.
final class GameRulesEntity: EntityTemplate {
    override class var systemImage: String {
        "list.bullet.clipboard"
    }

    override func build(_ entity: EntityID) {
        add(GameRules.self, to: entity)
    }
}

final class GameRules: CodeComponent {
    @UntoldAttribute("Round Length", range: 10 ... 600, step: 5) var roundSeconds: Float = 90
    @UntoldAttribute("Score To Win", range: 1 ... 100) var scoreToWin: Int = 10
    @UntoldAttribute var suddenDeath = false

    private(set) var timeLeft: Float = 0
    private(set) var isRoundOver = false

    override class var actions: [ComponentAction] {
        [ComponentAction("Restart Round") { ($0 as? GameRules)?.restartRound() }]
    }

    override func onStart() {
        restartRound()
    }

    override func onUpdate(deltaTime: Float) {
        guard isRoundOver == false else { return }
        timeLeft -= deltaTime
        if timeLeft <= 0 {
            timeLeft = 0
            isRoundOver = true
            Logger.log(message: "[GameRules] Time is up after \(Int(roundSeconds)) seconds\(suddenDeath ? "; sudden death." : ".")")
        }
    }

    func restartRound() {
        timeLeft = roundSeconds
        isRoundOver = false
    }
}
