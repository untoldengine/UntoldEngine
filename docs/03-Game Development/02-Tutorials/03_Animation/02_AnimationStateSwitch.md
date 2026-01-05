# Animation State Switching

Learn how to switch between different animations based on player input and game state.

---

## Overview

This tutorial shows you how to:
- Create a state-based animation system
- Switch between idle, running, and jumping animations
- Trigger animations based on input

---

## Prerequisites

This tutorial assumes you have:
- Completed the [Play Animation tutorial](./01_PlayAnimation.md)
- A project with multiple animations loaded (idle, running, jumping)
- An entity with a skeleton that supports animation

For complete API documentation:

➡️ **[Animation System API](../../04-Engine%20Development/03-Engine%20Systems/UsingAnimationSystem.md)**

---

## Step 1: Set Up Animation States

Define an enum to represent your animation states:

```swift path=null start=null
enum PlayerState {
    case idle
    case running
    case jumping
}

class GameScene {
    var player: EntityID!
    var playerState: PlayerState = .idle
    
    init() {
        // ... setup code ...
        startGameSystems()
        
        // Register input
        InputSystem.shared.registerKeyboardEvents()
        
        player = findEntity(name: "Player")
        
        // Load all animations -- ignore if you linked all three animations through the editor.
        loadPlayerAnimations()
        
        // Start with idle
        changeAnimation(entityId: player, name: "idle")
    }
    
    func loadPlayerAnimations() {
        setEntityAnimations(
            entityId: player,
            filename: "idle",
            withExtension: "usdc",
            name: "idle"
        )
        
        setEntityAnimations(
            entityId: player,
            filename: "running",
            withExtension: "usdc",
            name: "running"
        )
        
        setEntityAnimations(
            entityId: player,
            filename: "jumping",
            withExtension: "usdc",
            name: "jumping"
        )
    }
}
```

---

## Step 2: Implement State Switching Logic

Create a function to handle state transitions:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    var playerState: PlayerState = .idle
    var isGrounded: Bool = true  // Track if player is on ground
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        updatePlayerState()
    }
    
    func updatePlayerState() {
        let oldState = playerState
        
        // Determine new state based on input and game conditions
        if !isGrounded {
            playerState = .jumping
        } else if isMovementKeyPressed() {
            playerState = .running
        } else {
            playerState = .idle
        }
        
        // Only change animation if state actually changed
        if playerState != oldState {
            switchToAnimation(for: playerState)
        }
    }
    
    func isMovementKeyPressed() -> Bool {
        return inputSystem.keyState.wPressed ||
               inputSystem.keyState.aPressed ||
               inputSystem.keyState.sPressed ||
               inputSystem.keyState.dPressed
    }
    
    func switchToAnimation(for state: PlayerState) {
        switch state {
        case .idle:
            changeAnimation(entityId: player, name: "idle")
            Logger.log(message: "Switched to idle animation")
            
        case .running:
            changeAnimation(entityId: player, name: "running")
            Logger.log(message: "Switched to running animation")
            
        case .jumping:
            changeAnimation(entityId: player, name: "jumping")
            Logger.log(message: "Switched to jumping animation")
        }
    }
}
```

---

## Step 3: Add Jump Trigger

Add space bar input to trigger jumping:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    var playerState: PlayerState = .idle
    var isGrounded: Bool = true
    var jumpTimer: Float = 0.0
    let jumpDuration: Float = 0.5  // Jump animation duration in seconds
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        handleJumpInput()
        updateJumpTimer(deltaTime: deltaTime)
        updatePlayerState()
    }
    
    func handleJumpInput() {
        // Trigger jump on space press (only if grounded)
        if inputSystem.keyState.spacePressed && isGrounded {
            isGrounded = false
            jumpTimer = jumpDuration
        }
    }
    
    func updateJumpTimer(deltaTime: Float) {
        // Count down jump timer
        if !isGrounded {
            jumpTimer -= deltaTime
            
            // Land when timer expires
            if jumpTimer <= 0.0 {
                isGrounded = true
                jumpTimer = 0.0
            }
        }
    }
    
    func updatePlayerState() {
        let oldState = playerState
        
        // Priority: jumping > running > idle
        if !isGrounded {
            playerState = .jumping
        } else if isMovementKeyPressed() {
            playerState = .running
        } else {
            playerState = .idle
        }
        
        if playerState != oldState {
            switchToAnimation(for: playerState)
        }
    }
}
```

---

## Step 4: Combine Animation with Movement

Integrate animation state switching with actual movement:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    var playerState: PlayerState = .idle
    var isGrounded: Bool = true
    var jumpTimer: Float = 0.0
    let moveSpeed: Float = 5.0
    let jumpDuration: Float = 0.5
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        handleJumpInput()
        updateJumpTimer(deltaTime: deltaTime)
        updatePlayerState()
        updatePlayerMovement(deltaTime: deltaTime)
    }
    
    func updatePlayerMovement(deltaTime: Float) {
        var movement = SIMD3<Float>(0, 0, 0)
        
        // Only move if grounded
        if isGrounded {
            if inputSystem.keyState.wPressed {
                movement.z += moveSpeed * deltaTime
            }
            if inputSystem.keyState.sPressed {
                movement.z -= moveSpeed * deltaTime
            }
            if inputSystem.keyState.aPressed {
                movement.x -= moveSpeed * deltaTime
            }
            if inputSystem.keyState.dPressed {
                movement.x += moveSpeed * deltaTime
            }
            
            if movement != SIMD3<Float>(0, 0, 0) {
                translateBy(entityId: player, delta: movement)
            }
        }
    }
}
```

---

## Advanced: State Machine Pattern

For more complex state management, consider using a proper state machine:

```swift path=null start=null
class AnimationStateMachine {
    var currentState: PlayerState = .idle
    var entityId: EntityID
    
    init(entityId: EntityID) {
        self.entityId = entityId
    }
    
    func canTransition(to newState: PlayerState) -> Bool {
        switch (currentState, newState) {
        case (.jumping, .idle), (.jumping, .running):
            // Can only exit jumping state when landing
            return false
        default:
            return true
        }
    }
    
    func transition(to newState: PlayerState) {
        guard canTransition(to: newState) else { return }
        
        if currentState != newState {
            currentState = newState
            playAnimation(for: newState)
        }
    }
    
    func playAnimation(for state: PlayerState) {
        let animationName: String
        switch state {
        case .idle:     animationName = "idle"
        case .running:  animationName = "running"
        case .jumping:  animationName = "jumping"
        }
        
        changeAnimation(entityId: entityId, name: animationName)
    }
}
```

---

## Summary

You've learned:

✅ Create animation states using enums  
✅ Switch animations based on game state  
✅ Trigger animations from input  
✅ Prevent animation flickering with state checks  
✅ Combine animations with movement logic

---

## API Reference

For complete Animation System documentation:

➡️ **[Animation System API](../../04-Engine%20Development/03-Engine%20Systems/UsingAnimationSystem.md)**

---

## Where to Go Next

- **Apply physics forces**: [../04_Physics/01_ApplyForce.md](../04_Physics/01_ApplyForce.md)
