//
//  Foot.cpp
//  Dribblr
//
//  Created by Harold Serrano on 5/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Foot.h"
#include "Ball.h"

Foot::Foot(Player *uPlayer):player(uPlayer){
    
}

Foot::~Foot(){
    
}

bool Foot::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //set shader for foot to be hidden
        setShader("vertexNonVisibleShader", "fragmentNonVisibleShader");
        
        //enable collision detection
        enableCollisionBehavior();
        
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

    }
    
}

void Foot::setKickBallParameters(float uKickMagnitude,U4DEngine::U4DVector3n &uKickDirection){
    
    kickMagnitude=uKickMagnitude;
    kickDirection=uKickDirection;
    
}
