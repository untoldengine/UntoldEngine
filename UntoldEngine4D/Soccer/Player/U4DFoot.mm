//
//  U4DFoot.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DFoot.h"
#include "U4DBall.h"
#include "CommonProtocols.h"

namespace U4DEngine {

    U4DFoot::U4DFoot(){
        
    }

    U4DFoot::~U4DFoot(){
        delete kineticAction;
    }

    //init method. It loads all the rendering information among other things.
    bool U4DFoot::init(const char* uModelName){
        
        if (loadModel(uModelName)) {
            
            //set shader for foot to be hidden
            setPipeline("nonvisible");
            
            kineticAction=new U4DEngine::U4DDynamicAction(this);
            
            //enable collision detection
            kineticAction->enableCollisionBehavior();
            
            kineticAction->pauseCollisionBehavior();
            
            //set player as a collision sensor. Meaning only detection is enabled but not the collision response
            kineticAction->setIsCollisionSensor(true);
            
            //I am of type
            kineticAction->setCollisionFilterCategory(kFoot);
            
            //I collide with type of ball.
            kineticAction->setCollisionFilterMask(kBall);
            
            //set a tag
            kineticAction->setCollidingTag("foot");
            
            //send info to the GPU
            loadRenderingInformation();
            
            return true;
        }
        
        return false;
    }

    void U4DFoot::update(double dt){
        
        if (kineticAction->getModelHasCollided()) {
            
            U4DBall *ball=U4DBall::sharedInstance();

            ball->setKickBallParameters(kickMagnitude, kickDirection);

            ball->changeState(kicked);

            kineticAction->pauseCollisionBehavior();
            
            
        }
        
    }

    void U4DFoot::setKickBallParameters(float uKickMagnitude, U4DVector3n &uKickDirection){
        
        kickMagnitude=uKickMagnitude;
        kickDirection=uKickDirection;
        
    }

}
