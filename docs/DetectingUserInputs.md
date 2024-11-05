# Detecting Inputs from user

The Untold Engine employs an `Input System` which detect key strokes and mouse movement from the user.

For example, if you want to detect if the user pressed the 'w' key, you would do the following:

```swift
    if inputSystem.keyState.wPressed == true{
        //...your code here... 
    }
```

Same logic applies for the 'a', 's' and 'd' key. 

Here is an example where the input system is used to detect the keys from the user and translate the entity accordingly.

```swift
    func moveCar(entityId: EntityID, dt: Float){

        // if not in game mode, then return
        if gameMode == false {
            return 
        }

        var speed:Float = 33.0
        var offset:Float = 3.5

        // position of entity
        var position:simd_float3 = getPosition(entityId: entityId)

        // forward vector of entity
        var forward:simd_float3 = getForwardVector(entityId:entityId)

        let up: simd_float3 = simd_float3(0.0, 1.0, 0.0)

        var right: simd_float3 = cross(forward, up)
        
        right = normalize(right)

        //check keys pressed
        if inputSystem.keyState.wPressed == true{
            position+=forward*speed*dt 
        }

        if inputSystem.keyState.sPressed == true{
            position-=forward*speed*dt 
        }

        if inputSystem.keyState.aPressed == true{
            position-=right*speed*dt 
        }

        if inputSystem.keyState.dPressed == true{
            position+=right*speed*dt 
        }

        translateTo(entityId:entityId, position: position)
    }

```

Previous: [Adding Light to your game](AddingLighttoyourgame.md)

