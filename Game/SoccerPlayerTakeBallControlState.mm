//
//  SoccerPlayerTakeBallControlState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerTakeBallControlState.h"
#include "SoccerPlayerDribbleState.h"
#include "SoccerPlayerGroundPassState.h"
#include "SoccerPlayerForwardKickState.h"
#include "SoccerBall.h"

SoccerPlayerTakeBallControlState* SoccerPlayerTakeBallControlState::instance=0;

SoccerPlayerTakeBallControlState::SoccerPlayerTakeBallControlState(){
    
}

SoccerPlayerTakeBallControlState::~SoccerPlayerTakeBallControlState(){
    
}

SoccerPlayerTakeBallControlState* SoccerPlayerTakeBallControlState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerTakeBallControlState();
    }
    
    return instance;
    
}

void SoccerPlayerTakeBallControlState::enter(SoccerPlayer *uPlayer){
    
    //set the control ball animation
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getHaltBallWithRightFootAnimation());
        
    }else{
     
        uPlayer->setNextAnimationToPlay(uPlayer->getHaltBallWithLeftFootAnimation());
        
    }
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
}

void SoccerPlayerTakeBallControlState::execute(SoccerPlayer *uPlayer, double dt){
    
    //stop ball motion if the feet collide with the ball and if it matches a keyframe 
    if ((uPlayer->getRightFootCollidedWithBall() || uPlayer->getLeftFootCollidedWithBall()) && uPlayer->getAnimationCurrentKeyframe()==3) {
        
        //adjust the ball to a good location to start dribbling
        
        SoccerBall *ball=uPlayer->getBallEntity();
        
        ball->removeKineticForces();
        
    }
    
    
    if (uPlayer->getButtonAPressed()) {
        
        SoccerPlayerGroundPassState *sidePassState=SoccerPlayerGroundPassState::sharedInstance();
        
        uPlayer->changeState(sidePassState);
    }
    
    //check if player should shoot
    if (uPlayer->getButtonBPressed()) {
        
        SoccerPlayerForwardKickState *forwardKickState=SoccerPlayerForwardKickState::sharedInstance();
        
        uPlayer->changeState(forwardKickState);
        
    }
    
    //if joystick is active go into dribble state
    if (uPlayer->getJoystickActive()) {
        
        SoccerPlayerStateInterface *dribbleState=SoccerPlayerDribbleState::sharedInstance();
        
        uPlayer->changeState(dribbleState);
        
    }
    

    
}

void SoccerPlayerTakeBallControlState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerTakeBallControlState::isSafeToChangeState(SoccerPlayer *uPlayer){
    
    return true;
}
