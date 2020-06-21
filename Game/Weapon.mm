//
//  Weapon.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/26/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Weapon.h"
#include "Bullet.h"
#include "UserCommonProtocols.h"

Weapon::Weapon(){
    
}

Weapon::~Weapon(){
    
}

bool Weapon::init(const char* uModelName){
    
    if(loadModel(uModelName)){
        
        //load rendering information
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
    
}

void Weapon::update(double dt){
    
}

void Weapon::shoot(){
    
    //get grandparent of bullet
    U4DEngine::U4DEntity *parent=getParent();

    U4DEngine::U4DEntity *grandParent=parent->getParent();
    
    //create a bullet
    Bullet *bullet=new Bullet();
    
    if(bullet->init("bullet")){
        
        //add the bullet to the scengraph as a child of Earth (U4DWorld)
        grandParent->addChild(bullet,0);
        
        U4DEngine::U4DVector3n pos=getAbsolutePosition();
        
        float weaponDimension=getModelDimensions().magnitude();
        
        weaponDimension*=0.5;
        
        //set the position of the bullet to be emitted from the barrel of the pistol
        U4DEngine::U4DMatrix3n m=getAbsoluteSpaceOrientation().transformQuaternionToMatrix3n();
        U4DEngine::U4DVector3n weaponBarrelPosition(-0.2,0.0,-0.1);
        U4DEngine::U4DVector3n bulletInitPosition=m*weaponBarrelPosition;
        
        pos=pos+bulletInitPosition*weaponDimension;
        
        bullet->translateTo(pos);
        
        //set the force direction
        U4DEngine::U4DVector3n forceDirection=parent->getViewInDirection();
        
        bullet->setForceDirection(forceDirection);
        
        bullet->changeState(shooting);
        
        
    }
    
}
