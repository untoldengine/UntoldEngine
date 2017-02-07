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
        
        kick=new U4DEngine::U4DAnimation(this);
        walking=new U4DEngine::U4DAnimation(this);
        
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
        
        
        if (loadAnimationToModel(kick, "kick", uBlenderFile)) {

            
            
        }
        
        if (loadAnimationToModel(walking, "walking", uBlenderFile)) {
            
            
            
        }
        
        
        loadRenderingInformation();
        
        //translate the player
        translateBy(0.0, getModelDimensions().y/2.0+0.2, 0.0);
        
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
            changeState(kInPossesionOfBall);
            
        }else{
            //apply collision with ball
            setCollisionFilterGroupIndex(kZeroGroupIndex);
            changeState(kNull);
        }
        
    }
    

    if (getState()==kWalking) {
        
        //if (getIsAnimationUpdatingKeyframe()) {
            
            U4DEngine::U4DVector3n view=getViewInDirection()*dt;
            translateBy(view);
        
        //}
        
    }else if (getState()==kInPossesionOfBall) {
        
        
    }else if (getState()==kAdvancingWithBall){
    
        
    }else if (getState()==kGroundPass) {
        
        if (getIsAnimationUpdatingKeyframe()) {
            
            //set the kick pass at this keyframe and interpolation time
            if (getAnimationCurrentKeyframe()==1 && getAnimationCurrentInterpolationTime()==0) {
                
                soccerBallEntity->changeState(kGroundPass);
                soccerBallEntity->setKickDirection(joyStickData);
                
                //apply collision with ball
                //setCollisionFilterGroupIndex(kZeroGroupIndex);
                
                changeState(kNull);
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
            
            
            break;
            
        case kAirPass:
            
            break;
            
        case kGroundPass:
        {
            setAnimation(kick);
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
