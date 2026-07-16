# Interaction / Gameplay Demo

Focused demo for a small gameplay loop using Untold Engine APIs.

Run it from the repository root:

```bash
swift run InteractionGameplayDemo
```

What it demonstrates:

- loading `.untold` gameplay assets from `Tests/UntoldEngineRenderTests/Resources`
- player input with `InputSystem`
- idle/running animation switching with `setEntityAnimations` and `changeAnimation`
- simple player movement through `setEntityKinetics` and `steerSeek`
- parenting the ball to the player with `setParent`
- rotating the child ball while the player moves

Controls:

- `WASD` moves the player
