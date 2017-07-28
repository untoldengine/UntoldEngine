//
//  SoccerPlayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayer.h"

SoccerPlayer::SoccerPlayer(){
    
}

SoccerPlayer::~SoccerPlayer(){
    
}

void SoccerPlayer::init(const char* uModelName, const char* uBlenderFile, const char* uTextureNormal){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        //setEnableShadow(true);
        
        setNormalMapTexture(uTextureNormal);
        
        //enableKineticsBehavior();
        //enableCollisionBehavior();
        
        //initMass(10.0);
        //initCoefficientOfRestitution(0.9);
        
        /*
        walkingAnimation=new U4DEngine::U4DAnimation(this);
        
        if (loadAnimationToModel(walkingAnimation, "walking", "walkinganimation.u4d")) {
        
            
        }
        */
        
        loadRenderingInformation();
        
    }
    
    
}

void SoccerPlayer::update(double dt){
    
}

void SoccerPlayer::playAnimation(){
    
    walkingAnimation->play();
    
}

void SoccerPlayer::pauseAnimation(){
    
    walkingAnimation->pause();
}

void SoccerPlayer::setPlayerHeading(U4DEngine::U4DVector3n& uHeading){
    
    //set view heading of player
    viewInDirection(uHeading);
    
}

void SoccerPlayer::applyForceToPlayer(float uVelocity, double dt){
    
    U4DEngine::U4DVector3n heading=getViewInDirection();
    
    heading.normalize();
    
    U4DEngine::U4DVector3n forceToPlayer=(heading*uVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    
}
