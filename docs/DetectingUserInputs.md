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

        //check keys pressed
        if inputSystem.keyState.wPressed == true{
             
        }

        if inputSystem.keyState.sPressed == true{
            
        }

        if inputSystem.keyState.aPressed == true{
            
        }

        if inputSystem.keyState.dPressed == true{
             
        }

        translateTo(entityId:entityId, position: position)
    }

```

Next: [Enabling Physics](physics.md)
Previous: [Adding Light to your game](AddingLighttoyourgame.md)

