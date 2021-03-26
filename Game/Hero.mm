//
//  Hero.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Hero.h"


Hero::Hero(){
    
}

Hero::~Hero(){
    
}

bool Hero::init(const char* uModelName){
    
    if (Player::init(uModelName)) {
        
        //setPipeline("nonvisible");
        
        U4DEngine::U4DVector3n viewDirectionVector(0.0,0.0,-1.0);
        setEntityForwardVector(viewDirectionVector);
        
        //set colliding tag to determine which object is colliding with
        setCollidingTag("herosoldier");
        
        //The filter category states: I am of type
        setCollisionFilterCategory(kHero);

        //And I collided with...
        setCollisionFilterMask(kBullet);
        
        changeState(idle);
        
        //send data to GPU
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
    
}

void Hero::update(double dt){
    
    Player::update(dt);

    
}




