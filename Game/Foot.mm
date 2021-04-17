//
//  Foot.cpp
//  Dribblr
//
//  Created by Harold Serrano on 5/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Foot.h"
#include "Ball.h"
#include "UserCommonProtocols.h"

Foot::Foot(Player *uPlayer):player(uPlayer){
    
}

Foot::~Foot(){
    
}

bool Foot::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //set shader for foot to be hidden
        setPipeline("nonvisible");
        
        //enable collision detection
        enableCollisionBehavior();
        
        pauseCollisionBehavior();
        
        //set player as a collision sensor. Meaning only detection is enabled but not the collision response
        setIsCollisionSensor(true);
        
        //I am of type
        setCollisionFilterCategory(kFoot);
        
        //I collide with type of ball.
        setCollisionFilterMask(kBall);
        
        //set a tag
        setCollidingTag("foot");
        
        //send info to the GPU
        loadRenderingInformation();
        
        return true;
        
    }
    
    return false;
    
}
   
void Foot::update(double dt){
    
    if (getModelHasCollided()) {
        
        Ball *ball=Ball::sharedInstance();

        ball->setKickBallParameters(kickMagnitude, kickDirection);

        ball->changeState(kicked);

        pauseCollisionBehavior();
    }
    
}

void Foot::setKickBallParameters(float uKickMagnitude,U4DEngine::U4DVector3n &uKickDirection){
    
    kickMagnitude=uKickMagnitude;
    kickDirection=uKickDirection;
    
}
