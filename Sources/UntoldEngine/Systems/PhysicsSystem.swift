//
//  File.swift
//  
//
//  Created by Harold Serrano on 11/9/24.
//

import Foundation
import simd

public func setMass(entityId: EntityID, mass: Float){
    
    //retrieve physics component
    guard let physics = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return
    }
    
    physics.mass=mass
    
}

public func applyForce(entityId: EntityID, force: simd_float3){

    //retrieve physics component
    guard let physics = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return
    }
    
    let mass=physics.mass
    
    physics.acceleration=force/mass
    
}

public func eulerIntegration(entityId: EntityID, deltaTime: Float){
    
    //retrieve physics component
    guard let physics = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return
    }
    
    //retrieve Transform component
    guard let transform = scene.get(component: Transform.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return
    }
    
    
    //update velocity
    physics.velocity+=physics.acceleration*deltaTime
    
    //update position
    transform.localSpace.columns.3.x += physics.velocity.x*deltaTime
    transform.localSpace.columns.3.y += physics.velocity.y*deltaTime
    transform.localSpace.columns.3.z += physics.velocity.z*deltaTime
}
