//
//  Enemy.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Enemy.h"

Enemy::Enemy(){
    
    
    
}

Enemy::~Enemy(){
    
}

bool Enemy::init(const char* uModelName){
    
    if(Player::init(uModelName)){
        
        changeState(patrol);
        
        //set colliding tag to determine which object is colliding with
        setCollidingTag("enemysoldier");
        
        //The filter category states: I am of type
        setCollisionFilterCategory(kEnemySoldier);

        //And I collided with...
        setCollisionFilterMask(kBullet);
        
        //send data to GPU
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
}

void Enemy::update(double dt){
    
    if(getModelHasCollided()){
        
        //get a list of entities it is colliding with
        for (auto n:getCollisionList()) {
            
            //check if entity is bullet
            if(n->getCollidingTag().compare("bullet")==0){
                
                pauseCollisionBehavior();
                
                changeState(dead);
                
            }
            
        }
        
    }
    
    Player::update(dt);
    
}
