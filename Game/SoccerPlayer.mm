//
//  SoccerPlayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayer.h"
#include "UserCommonProtocols.h"

void SoccerPlayer::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        forwardKick=new U4DEngine::U4DAnimation(this);
        walking=new U4DEngine::U4DAnimation(this);
        running=new U4DEngine::U4DAnimation(this);
        
        sidePass=new U4DEngine::U4DAnimation(this);
        forwardCarry=new U4DEngine::U4DAnimation(this);
        sideCarryRight=new U4DEngine::U4DAnimation(this);
        sideCarryLeft=new U4DEngine::U4DAnimation(this);
        
        
        //set collision info
        initMass(10.0);
        initCoefficientOfRestitution(0.9);
        enableCollisionBehavior();
        
        //set collision filters
        setCollisionFilterCategory(kSoccerPlayer);
        setCollisionFilterMask(kSoccerBall);
        
        //set player collision with ball filter to occur
        setCollisionFilterGroupIndex(kZeroGroupIndex);
        
        changeState(kNull);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        if (loadAnimationToModel(walking, "walking", "walkinganimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(forwardKick, "forwardkick", "forwardkickanimationscript.u4d")) {

            
            
        }
        
        if (loadAnimationToModel(running, "running", "runninganimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(sidePass, "sidepass", "sidepassanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(forwardCarry, "forwardcarry", "forwardcarryanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(sideCarryLeft, "sidecarryleft", "sidecarryleftanimationscript.u4d")) {
            
            
            
        }

        if (loadAnimationToModel(sideCarryRight, "sidecarryright", "sidecarryrightanimationscript.u4d")) {
            
            
            
        }
        
        
        loadRenderingInformation();
        
        //translate the player
        translateBy(-9.0, getModelDimensions().y/2.0+1.3, 0.0);
        
    }
    
    
}

void SoccerPlayer::update(double dt){
    
    //check if model has collided with ball
    if (getModelHasCollided()) {
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        
        U4DEngine::U4DVector3n relativePositionOfBall=soccerBallEntity->getAbsolutePosition()-getAbsolutePosition();
        
        view.normalize();
        relativePositionOfBall.normalize();
        
        float inSameDirection=view.dot(relativePositionOfBall);
        
        if (inSameDirection>=0) {
            
            //set player collision with ball filter not to occur
            setCollisionFilterGroupIndex(kNegativeGroupIndex);
            changeState(kGroundPass);
            
        }else{
            //apply collision with ball
            setCollisionFilterGroupIndex(kZeroGroupIndex);
            changeState(kNull);
        }
        
    }
    

    if (getState()==kWalking) {
        
        if (getIsAnimationUpdatingKeyframe()) {
            
        U4DEngine::U4DVector3n view=getViewInDirection();
        //view.normalize();
        view*=5.0*dt;
        
        translateBy(view);
        
        }
        
    }else if (getState()==kRunning) {
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        //view.normalize();
        view*=10.0*dt;
        
        translateBy(view);
        
    }else if (getState()==kInPossesionOfBall) {
        
        
    }else if (getState()==kAdvancingWithBall){
    
        
    }else if (getState()==kGroundPass) {
        
        if (getIsAnimationUpdatingKeyframe()) {
            
            //set the kick pass at this keyframe and interpolation time
            if (getAnimationCurrentKeyframe()==3 && getAnimationCurrentInterpolationTime()==0) {
                
                joyStickData.normalize();
                soccerBallEntity->changeState(kGroundPass);
                soccerBallEntity->setKickDirection(joyStickData);
                
                //apply collision with ball
                //setCollisionFilterGroupIndex(kZeroGroupIndex);
                
                //changeState(kNull);
            }
        }
        
    }
    
}

void SoccerPlayer::changeState(GameEntityState uState){
    
    removeAnimation();
    
    
    setState(uState);
    
    switch (uState) {
            
        case kWalking:
            
            setAnimation(walking);
            
            
            break;
            
        case kRunning:
            
            setAnimation(running);
            
            
            break;
            
        case kAirPass:
            
            break;
            
        case kGroundPass:
        {
            setAnimation(sidePass);
            setPlayAnimationContinuously(false);
            
        }
            
            break;
            
        case kInPossesionOfBall:
            
            break;
            
        default:
            
            break;
    }
    
    if (getAnimation()!=NULL) {
        
        playAnimation();
        
    }
    
}

void SoccerPlayer::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState SoccerPlayer::getState(){
    return entityState;
}

void SoccerPlayer::setBallEntity(SoccerBall *uSoccerBall){
    
    soccerBallEntity=uSoccerBall;
}
