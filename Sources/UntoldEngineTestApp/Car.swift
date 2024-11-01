import UntoldEngine
import simd
import Foundation

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


