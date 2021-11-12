//
//  Foot.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Foot.h"
#include "Ball.h"
#include "UserCommonProtocols.h"

Foot::Foot(){
    
}

Foot::~Foot(){
    delete kineticAction;
}

//init method. It loads all the rendering information among other things.
bool Foot::init(const char* uModelName){
    
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

void Foot::update(double dt){
    
    if (kineticAction->getModelHasCollided()) {
        
        Ball *ball=Ball::sharedInstance();

        ball->setKickBallParameters(kickMagnitude, kickDirection);

        ball->changeState(kicked);

        kineticAction->pauseCollisionBehavior();
        
        
    }
    
}

void Foot::setKickBallParameters(float uKickMagnitude,U4DEngine::U4DVector3n &uKickDirection){
    
    kickMagnitude=uKickMagnitude;
    kickDirection=uKickDirection;
    
}

