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
        translateBy(-3.0, 0.0, -3.0);
        
        //U4DEngine::U4DVector2n drag(0.6,0.5);
        //setDragCoefficient(drag);
        
        //U4DEngine::U4DVector3n grav(0,0,0);
        //setGravity(grav);
        
        loadRenderingInformation();
    }
    
    
}

void SoccerBall::update(double dt){
    
    if (getState()==kPass) {
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        U4DEngine::U4DVector3n pass(view.x*5000.0,0.0,view.z*5000.0);
        
        applyForce(pass);
        
        changeState(kNull);
        
    }else if (getState()==kVolley){
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        U4DEngine::U4DVector3n kick(view.x*5000.0,5000.0,view.z*5000.0);
        //U4DEngine::U4DVector3n kick(0.0,5000.0,0.0);
        applyForce(kick);
        
        changeState(kNull);
        
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
