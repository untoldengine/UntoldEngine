//
//  Rifle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Rifle.h"
#include "Bullet.h"
#include "UserCommonProtocols.h"

Rifle::Rifle(){
    
}

Rifle::~Rifle(){
    
}

bool Rifle::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
}

void Rifle::update(double dt){
    
}


void Rifle::shoot(U4DEngine::U4DVector3n &uDirection){
    
    //the rifle was initially attached to the soldier, but we need to get access to the world pointer, i.e. the grandparent of the rifle. The bullet object is attached to the grandparent object.
    U4DEngine::U4DEntity *parent=getParent();
    U4DEngine::U4DEntity *grandParent=parent->getParent();
    
    Bullet *bullet=new Bullet();
    
    if(bullet->init("bullet")){
        
        grandParent->addChild(bullet);
        
        U4DEngine::U4DVector3n pos=getAbsolutePosition();
        
        bullet->translateTo(pos);
        
        bullet->setForceDirection(uDirection);
        
        bullet->changeState(shot);
    }
}
