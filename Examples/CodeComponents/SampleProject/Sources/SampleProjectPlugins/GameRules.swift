import UntoldComponentKit
import UntoldEngine

// A kind of entity with nothing to show at all, in the editor or in the game.
//
// The rules of a match are properties and behaviour. They are an entity so the scene saves
// them and the Inspector edits them, and that entity needs neither geometry nor a marker: it
// is found by name in the hierarchy. An entity plugin runs through play like a component does,
// so the round timer lives right here.

/// The "Game Rules" row on the editor's Entities shelf.
final class GameRulesEntity: EntityPlugin {
    @UntoldAttribute("Round Length", range: 10 ... 600, step: 5) var roundSeconds: Float = 90
    @UntoldAttribute("Score To Win", range: 1 ... 100) var scoreToWin: Int = 10
    @UntoldAttribute var suddenDeath = false

    private(set) var timeLeft: Float = 0
    private(set) var isRoundOver = false

    override class var systemImage: String {
        "list.bullet.clipboard"
    }

    override class var actions: [PluginAction] {
        [PluginAction("Restart Round") { ($0 as? GameRulesEntity)?.restartRound() }]
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
