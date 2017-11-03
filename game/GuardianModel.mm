//
//  GuardianModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "GuardianModel.h"

GuardianModel::GuardianModel(){
    
}

GuardianModel::~GuardianModel(){
    
    delete walkingAnimation;
}

void GuardianModel::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(true);
        
        //setNormalMapTexture(uTextureNormal);
        
        //enableKineticsBehavior();
        //enableCollisionBehavior();
        
        //initMass(10.0);
        //initCoefficientOfRestitution(0.9);
        
       
        walkingAnimation=new U4DEngine::U4DAnimation(this);
        
        if (loadAnimationToModel(walkingAnimation, "walking", "guardianscript.u4d")) {
        
            
        }
        
        
        loadRenderingInformation();
        
    }
    
    translateBy(0.0, 3.0, 0.0);
    
}

void GuardianModel::update(double dt){
    
}

void GuardianModel::playAnimation(){
    
    walkingAnimation->play();
    
}

void GuardianModel::stopAnimation(){
    
    walkingAnimation->stop();
}

void GuardianModel::setPlayerHeading(U4DEngine::U4DVector3n& uHeading){
    
    //set view heading of player
    viewInDirection(uHeading);
    
}

void GuardianModel::applyForceToPlayer(float uVelocity, double dt){
    
    U4DEngine::U4DVector3n heading=getViewInDirection();
    
    heading.normalize();
    
    U4DEngine::U4DVector3n forceToPlayer=(heading*uVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    
}
