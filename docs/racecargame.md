
# Making Your First Game: A Simple Race Car Game

Welcome to your first tutorial on using the **Untold Engine** to create a simple race car game. This guide will walk you through setting up a basic game scene, adding a controllable vehicle, and implementing a camera follow system. By the end of this tutorial, you'll have a functioning race car game with AI-driven opponent cars that simulate a competitive experience.

## 1. Create the GameScene Class
The `GameScene` class is the foundation of your game, where you'll set up the initial game state and write the core logic. Begin by defining this class.

```swift
// GameScene is where you would initialize your game and write the game logic.
class GameScene {

    init() {}
}
```

This class will act as the entry point for loading your game assets, initializing entities, and managing updates throughout the game loop.

## 2. Declare the Entities and Camera Parameters
For this tutorial, you'll control a blue car. Additionally, the camera will follow this car, requiring parameters to track its position.

```swift
class GameScene {

    // Entity which we will control with the WASD keys  
    var bluecar: EntityID!

    // Camera follow parameters to follow behind the blue car
    var targetPosition: simd_float3 = simd_float3(0.0, 0.0, 0.0)
    var offset: simd_float3 = simd_float3(0.0, 4.0, 8.0)

    init() {}
}
```

Declaring these properties will allow your game logic to reference the main car and position the camera appropriately.

## 3. Set the Camera LookAt Location & Load the Scene
Next, configure the camera to focus on a specific point and load the initial scene assets.

```swift
init() {
    // Set the camera to look at a point
    camera.lookAt(
      eye: simd_float3(0.0, 6.0, 35.0), target: simd_float3(0.0, 2.0, 0.0),
      up: simd_float3(0.0, 1.0, 0.0))
    
    // Load assets in bulk
    loadBulkScene(filename: "racetrack", withExtension: "usdc")

    // Load individual assets
    loadScene(filename: "bluecar", withExtension: "usdc")
    loadScene(filename: "redcar", withExtension: "usdc")
    loadScene(filename: "yellowcar", withExtension: "usdc")
    loadScene(filename: "orangecar", withExtension: "usdc")
}
```

The `camera.lookAt` function sets the camera's initial view direction, ensuring it captures the main action. Loading assets prepares your game world with elements like the track and cars.

## 4. Create the Entity
Create and position the main entity, in this case, the blue car that players will control.

```swift
init() {
    // ... load scene code...

    // Set entity for the blue car 
    bluecar = createEntity()

    // Link the mesh to the entity
    addMeshToEntity(entityId: bluecar, name: "bluecar")

    // Position the blue car
    translateTo(entityId: bluecar, position: simd_float3(2.5, 0.75, 20.0))
}
```

This step ensures your blue car entity is initialized, linked with the appropriate mesh, and placed in the starting position.

## 5. Create a Directional Light
To enhance the visual fidelity of the game, add a light source that simulates sunlight.

```swift
init() {
    // ... load scene code ...

    // Create a directional light entity (e.g., sun)
    let sunEntity: EntityID = createEntity()
    let sun: DirectionalLight = DirectionalLight()
    lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
}
```

Lighting adds depth and realism to your game scene, making the environment more visually appealing.

## 6. Move the Car with WASD Keys and Set the Camera to Follow
To bring your car to life, implement the `update` function that will handle user inputs and make the camera follow the car.

```swift
func update(_ deltaTime: Float) {
    moveCar(entityId: bluecar, dt: deltaTime)
    updateCameraFollow()
}
```

This function will be called every frame, updating the car's position based on user input and adjusting the camera's position accordingly.

## 7. Implement the Move Car Function
The `moveCar` function handles user input to move the car forward, backward, and sideways.

```swift
func moveCar(entityId: EntityID, dt: Float) {
    if gameMode == false {
        return
    }

    let speed: Float = 33.0
    var position: simd_float3 = getPosition(entityId: entityId)
    let forward: simd_float3 = getForwardVector(entityId: entityId)
    let up: simd_float3 = simd_float3(0.0, 1.0, 0.0)
    var right: simd_float3 = normalize(cross(forward, up))

    if inputSystem.keyState.wPressed {
        position += forward * speed * dt
    }
    if inputSystem.keyState.sPressed {
        position -= forward * speed * dt
    }
    if inputSystem.keyState.aPressed {
        position -= right * speed * dt
    }
    if inputSystem.keyState.dPressed {
        position += right * speed * dt
    }

    translateTo(entityId: entityId, position: position)
}
```

This function checks for key presses and moves the car accordingly. The `inputSystem` detects if the W, A, S, or D keys are pressed, and the car is translated in the appropriate direction.

## 8. Implement the Camera Follow Function
Create a function that keeps the camera smoothly following the car.

```swift
func updateCameraFollow() {
    if gameMode == false {
        return
    }

    var cameraPosition: simd_float3 = camera.getPosition()
    targetPosition = getPosition(entityId: bluecar)
    targetPosition.x = 0.0
    let desiredPosition: simd_float3 = targetPosition + offset

    cameraPosition = lerp(start: cameraPosition, end: desiredPosition, t: smoothSpeed)
    camera.translateTo(cameraPosition.x, cameraPosition.y, cameraPosition.z)
}

func lerp(start: simd_float3, end: simd_float3, t: Float) -> simd_float3 {
    return start * (1.0 - t) + end * t
}
```

The `lerp` function smoothly interpolates between the current camera position and the desired position, creating a smooth following effect.

## 9. Create the Opponent Car Class
To simulate competition, create an opponent car class with its own movement logic.

```swift
class Car{

    var entityId:EntityID!
    var velocity:simd_float3=simd_float3(0.0,0.0,0.0)
    var targetPosition:simd_float3=simd_float3(-1.0,1.0,-230.0)
    var maxSpeed:Float=Float.random(in:15...21) 
    var arrivalRadius:Float=2.0

    var speedChangeInterval:Float=2.0 
    var timeSinceSpeedChanged:Float=0.0 

    init(name:String, position:simd_float3){

        //first, you need to create an entity ID 
        entityId = createEntity()

        //next, add a mesh to the entity. name refers to the name of the model in the usdc file.
        addMeshToEntity(entityId: entityId, name: name)

        translateTo(entityId: entityId, position: position)

        //target end position for the game
        targetPosition=simd_float3(position.x,1.0,-230.0)
    }

    func update(dt:Float){
       
        if gameMode == false {
            return
        }

        timeSinceSpeedChanged += Float(TimeInterval(dt))


        //change speed randomly every few seconds 
        if timeSinceSpeedChanged >= speedChangeInterval{

            maxSpeed = Float.random(in: 19...21)
            timeSinceSpeedChanged = 0.0 //reset time
        }

        var position=getPosition(entityId: entityId)
        
        //close enough
        if length(targetPosition-position)<0.1{
            return 
        }

        let toTarget:simd_float3=targetPosition-position

        let distance:Float=length(toTarget)

        //calculate the desired speed based on how close the car is to the target
        
        var desiredSpeed:Float 

        if(distance<arrivalRadius){
            desiredSpeed = maxSpeed*(distance/arrivalRadius)
        }else{
            desiredSpeed = maxSpeed 
        }
        
        //calculate the desired velocity 
        let desiredVelocity=normalize(toTarget)*desiredSpeed

        //steering force:
        let steering:simd_float3=desiredVelocity-velocity 

        //Euler integration to update position and velocity
        velocity=velocity+steering*dt    //v=v+a*t  
        position=position+velocity*dt  //x=x+v*t 

        translateTo(entityId: entityId, position: position)

    }

}

```

## 10. Declare a Vector of Car Instances

To manage multiple opponent cars, create an array to store Car instances in your GameScene class.

```swift
class GameScene {
    // ... other declarations here ...

    // Opponent car parameters
    var cars: [Car] = []
}

```

This allows you to hold and manage multiple AI cars, enabling gameplay that feels dynamic and competitive.

## 11. Create Instances for Opponent Cars

In the init method, instantiate each opponent car and add it to the cars array.

```swift
init() {
    // ... other initializations here ...

    // Create instances for each opponent car
    let redCar = Car(name: "redcar", position: simd_float3(-2.5, 0.75, 20.0))
    let yellowCar = Car(name: "yellowcar", position: simd_float3(-2.5, 0.75, 10.0))
    let orangeCar = Car(name: "orangecar", position: simd_float3(2.5, 0.75, 10.0))

    cars.append(redCar)
    cars.append(yellowCar)
    cars.append(orangeCar)
}
```

Creating these instances sets up the initial conditions for the race, populating your game with AI competitors.

## 12. Update the Cars' Positions

To update the AI cars' movements, add logic to the update method to iterate over each Car instance.

```swift
func update(_ deltaTime: Float) {
    // ... other updates here ...

    for car in cars {
        car.update(dt: deltaTime)
    }
}

```

This will ensure that all opponent cars are updated each frame, providing a dynamic racing experience.

With these steps, your game is ready to simulate a race with controllable and AI-driven cars. Now press "L" on your keyboard to start the game and drive with the WASD keys.
