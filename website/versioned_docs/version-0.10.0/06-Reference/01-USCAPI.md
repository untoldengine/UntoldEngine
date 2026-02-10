# Untold Script Core API

Use this page as a compact checklist of the most-used USC (Untold Script Core) DSL calls. All snippets assume you’re inside a `buildScript` closure on the current entity (`self`).

---

## Lifecycle
- `onStart()` – one-time init per play.
- `onUpdate()` – every frame.
- `onEvent("Name")` – custom triggers.
- `onCollision(tag:)` – **planned** (not yet available).

## Properties (get/set)
Supported keys: `.position`, `.scale`, `.velocity`, `.acceleration`, `.mass`, `.angularVelocity` (write-only today), `.intensity`, `.color`, `.deltaTime`.
```swift
.getProperty(.position, as: "pos")
.setProperty(.position, toVariable: "nextPos")
.setProperty(.velocity, to: simd_float3(0, 2, 0))
```

## Input
```swift
.ifKeyPressed("W") { n in n.log("forward") }
.ifKeyReleased("Space") { n.log("jump released") }
.getKeyState("w", as: "wPressed")
```

## Transform
```swift
.translateTo(simd_float3(0, 1, 0))
.translateBy(simd_float3(0, 0, 1))
.rotateTo(degrees: 45, axis: simd_float3(0, 1, 0))
.rotateBy(degrees: .float(5), axis: simd_float3(0, 1, 0))
.lookAt("TargetEntity")
```

## Animation
```swift
.playAnimation("Walk", loop: true)
.stopAnimation()
```

## Physics (forces/velocity)
```swift
.applyForce(force: simd_float3(0, 10, 0))
.applyLinearImpulse(direction: .vec3(x: 0, y: 1, z: 0), magnitude: .float(5))
.setLinearVelocity(.vec3(x: 0, y: 0, z: 5))
.addLinearVelocity(.vec3(x: 0, y: 0, z: -1))
.clampLinearSpeed(min: .float(0), max: .float(8))
.clearVelocity()
.clearAngularVelocity()
.clearForces()
.setGravityScale(0.5)
.pausePhysicsComponent(isPaused: true)
```

## Steering (vectors or side effects)
```swift
.seek(targetPosition: .vec3(x: 10, y: 0, z: 0), maxSpeed: .float(5), result: "steer")
.flee(threatPosition: .vec3(x: 0, y: 0, z: 0), maxSpeed: .float(6), result: "steer")
.arrive(targetPosition: .vec3(x: 0, y: 0, z: 0), maxSpeed: .float(6), slowingRadius: .float(2), result: "steer")
.pursuit(targetEntity: .string("Player"), maxSpeed: .float(6), result: "steer")
.evade(threatEntity: .string("Enemy"), maxSpeed: .float(6), result: "steer")
.steerSeek(targetPosition: .variableRef("targetPos"), maxSpeed: .variableRef("maxSpeed"), deltaTime: .variableRef("dt"))
.steerArrive(targetPosition: .variableRef("targetPos"), maxSpeed: .variableRef("maxSpeed"), slowingRadius: .variableRef("slow"), deltaTime: .variableRef("dt"))
.steerFlee(threatPosition: .variableRef("threatPos"), maxSpeed: .variableRef("maxSpeed"), deltaTime: .variableRef("dt"))
.steerPursuit(targetEntity: .string("Target"), maxSpeed: .float(6), deltaTime: .float(0.016))
.orbit(centerPosition: .vec3(x: 0, y: 0, z: 0), radius: .float(5), maxSpeed: .float(4), deltaTime: .float(0.016))
.alignOrientation(deltaTime: .float(0.016), turnSpeed: .float(1.0))
```

## Camera
```swift
.cameraMoveTo(.vec3(x: 0, y: 3, z: -10))
.cameraMoveBy(.vec3(x: 1, y: 0, z: 0))
.cameraRotate(pitch: .float(0.02), yaw: .float(-0.08))
.cameraFollow(target: .string("Player"),
              offset: .vec3(x: 0, y: 3, z: -6),
              smoothFactor: .float(5),
              deltaTime: .float(0.016))
.cameraFollowLocal(target: .string("Player"),
                   localOffset: .vec3(x: 0, y: 2, z: -4),
                   smoothFactor: .float(5),
                   deltaTime: .float(0.016))
.cameraOrbitTarget(target: .string("Boss"),
                   radius: .float(12),
                   speed: .float(1.5),
                   deltaTime: .float(0.016),
                   offsetY: .float(1.5))
.cameraMoveWithInput(speedVar: "moveSpeed",
                     deltaTimeVar: "dt",
                     wVar: "wPressed", aVar: "aPressed",
                     sVar: "sPressed", dVar: "dPressed",
                     qVar: "qPressed", eVar: "ePressed")
```

## Math (variables only)
```swift
.addFloat("a", "b", as: "sum")
.addFloat("a", literal: 1, as: "sum")
.subFloat("a", "b", as: "diff")
.mulFloat("a", "b", as: "prod")
.divFloat("a", "b", as: "quot")
.addVec3("v1", "v2", as: "sum")
.scaleVec3("v", by: "s", as: "out")
.scaleVec3("v", literal: 2, as: "out")
.lengthVec3("v", as: "len")
.normalizeVec3("v", as: "unit")
.dotVec3("a", "b", as: "dot")
.crossVec3("a", "b", as: "cross")
.lerpVec3(from: "a", to: "b", t: "t", as: "out")
.lerpFloat(from: "a", to: "b", t: "t", as: "out")
.reflectVec3("v", normal: "n", as: "reflected")
.projectVec3("v", onto: "axis", as: "proj")
.angleBetweenVec3("a", "b", as: "angleDeg")
.clampFloat("speed", min: "minSpeed", max: "maxSpeed", as: "clamped")
.clampVec3("vel", min: "minVel", max: "maxVel", as: "clampedVel")
```

## Flow / Variables / Debug
```swift
.ifCondition(lhs: .variableRef("speed"), .greater, rhs: .float(10)) { n in n.log("Too fast") }
.ifGreater("health", than: 0) { n in n.log("Alive") }.else { n in n.log("Dead") }
.ifEqual("flag", to: true) { n in n.log("Flag set") }
.setVariable("speed", to: 5.0)
.setVariable("dir", to: simd_float3(0, 0, 1))
.setVariable("copy", fromVariable: "speed")
.log("Hello")
.logValue("velocity", value: .variableRef("vel"))
```

> Tip: If you need an entity other than `self`, use names in your instructions (e.g., `.lookAt("TargetName")`) or stash them in variables, then call `findEntity`-driven instructions like `pursuit`/`evade`.

