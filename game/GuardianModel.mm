//
//  GuardianModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/19/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "GuardianModel.h"
#include "GuardianStateManager.h"
#include "GuardianStateInterface.h"
#include "GuardianIdleState.h"
#include "GuardianRunState.h"
#include "GuardianJumpState.h"
#include "UserCommonProtocols.h"

GuardianModel::GuardianModel():ateCoin(false){
    
    stateManager=new GuardianStateManager(this);
    
}

GuardianModel::~GuardianModel(){
    
    U4DEngine::U4DEntity *parent=getParent();
    
    parent->removeChild(this);
    
    delete jumpAnimation;
    delete runAnimation;
    delete stateManager;
}

bool GuardianModel::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(true);
        
        setCollidingTag("player");
        
        //setNormalMapTexture(uTextureNormal);
        
        animationManager=new U4DEngine::U4DAnimationManager();

        enableKineticsBehavior();
        enableCollisionBehavior();
        
        initMass(10.0);
        initCoefficientOfRestitution(0.9);
        
        setCollisionFilterCategory(kPlayer);
        setCollisionFilterMask(kCube);
        
        setIsCollisionSensor(true);
        
        runAnimation=new U4DEngine::U4DAnimation(this);
        
        if (loadAnimationToModel(runAnimation, "walking", "blenderscript.u4d")) {
        
            
        }
        
        animationManager->setAnimationToPlay(runAnimation);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,-1);
        
        setEntityForwardVector(viewDirectionVector);
        
        changeState(GuardianIdleState::sharedInstance());
        
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
    
}

void GuardianModel::update(double dt){
    
    if (getModelHasCollided()) {
        
        ateCoin=true;
        
    }
    
    stateManager->update(dt);
}

void GuardianModel::changeState(GuardianStateInterface* uState){
    
    stateManager->safeChangeState(uState);
    
}

bool GuardianModel::guardianAte(){
    
    return ateCoin;
}

void GuardianModel::resetAteCoin(){
    
    ateCoin=false;
}

void GuardianModel::playAnimation(){
    
    //runAnimation->play();
    animationManager->playAnimation();
}

void GuardianModel::stopAnimation(){
    
    //runAnimation->stop();
    animationManager->stopAnimation();
    
}

void GuardianModel::setPlayerHeading(U4DEngine::U4DVector3n& uHeading){
    
    float fieldLength=1000.0;
    
    //set view heading of player
    uHeading.x*=fieldLength;
    uHeading.z*=fieldLength;
    uHeading.y=0.86;
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

bool GuardianModel::handleMessage(Message &uMsg){
    
    return stateManager->handleMessage(uMsg);
    
}
