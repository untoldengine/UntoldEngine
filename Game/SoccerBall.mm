//
//  SoccerBall.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerBall.h"
void SoccerBall::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        initInertiaTensorType(U4DEngine::sphericalInertia);
        initCoefficientOfRestitution(0.5);
        initMass(1.0);
        //initialize everything else here
        enableCollisionBehavior();
        enableKineticsBehavior();
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        setEntityForwardVector(viewDirectionVector);
        
        setState(kNull);
        //setBroadPhaseBoundingVolumeVisibility(true);
        //setNarrowPhaseBoundingVolumeVisibility(true);
        
        //U4DEngine::U4DVector2n drag(0.0,0.0);
        //setDragCoefficient(drag);
        
        U4DEngine::U4DVector3n grav(0,0,0);
        //setGravity(grav);
        
        loadRenderingInformation();
    }
    
    
}

void SoccerBall::update(double dt){
    
    float forceMagnitude=20.0;
    
    if (getModelHasCollided()) {
        //changeState(kNull);
        //clearForce();
        //clearMoment();
    }
    
    if (getState()==kPass) {
        
        U4DEngine::U4DVector3n forceDirection=joyStickData*forceMagnitude;
        
        U4DEngine::U4DVector3n pass(forceDirection.x,0.0,-forceDirection.y);
        
        addForce(pass);
        
        //rotate
        U4DEngine::U4DVector3n up(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n passVector=pass;
        
        //passVector.normalize();
        
        U4DEngine::U4DVector3n axis=up.cross(passVector);
        
        addMoment(axis);
        
        //changeState(kNull);
        
    }else if (getState()==kVolley){
    
        U4DEngine::U4DVector3n forceDirection=joyStickData*forceMagnitude*-1.0;
        
        U4DEngine::U4DVector3n pass(forceDirection.x,0.0,-forceDirection.y);
        
        addForce(pass);
        
        //rotate
        U4DEngine::U4DVector3n up(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n passVector=pass;
        
        //passVector.normalize();
        
        U4DEngine::U4DVector3n axis=up.cross(passVector);
        
        addMoment(axis);
        
    }else if (getState()==kShoot){
        
        
    }
    
}

void SoccerBall::changeState(GameEntityState uState){
    
    setState(uState);
    
    switch (uState) {
            
        case kPass:
            
            
            break;
            
        case kVolley:
            
            break;
            
        case kShoot:
            
            break;
            
        default:
            
            break;
    }
    
}

void SoccerBall::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState SoccerBall::getState(){
    return entityState;
}
