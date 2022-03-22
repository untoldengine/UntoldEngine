//
//  U4DPlayerStateJog.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateJog.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateHalt.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DBall.h"
#include "U4DFoot.h"

namespace U4DEngine {

    U4DPlayerStateJog* U4DPlayerStateJog::instance=0;

    U4DPlayerStateJog::U4DPlayerStateJog(){
        name="jogging";
    }

    U4DPlayerStateJog::~U4DPlayerStateJog(){
        
    }

    U4DPlayerStateJog* U4DPlayerStateJog::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPlayerStateJog();
        }
        
        return instance;
        
    }

    void U4DPlayerStateJog::enter(U4DPlayer *uPlayer){
        

        U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
        
        //play the running animation
        U4DAnimation *currentAnimation=uPlayer->jogAnimation;

        if (currentAnimation!=nullptr) {
            uPlayer->animationManager->setAnimationToPlay(currentAnimation);
        }
        
        //set speed
        uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveJogMaxSpeed"));

        //set the distance to stop
        uPlayer->arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("arriveJogStopRadius"));
        
        //set the distance to start slowing down
        uPlayer->arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("arriveJogSlowRadius"));
        
        uPlayer->foot->kineticAction->pauseCollisionBehavior();
    }

    void U4DPlayerStateJog::execute(U4DPlayer *uPlayer, double dt){
        
        //set the target entity to approach
        U4DAnimation *currentAnimation=uPlayer->jogAnimation;

        uPlayer->updateFootSpaceWithAnimation(currentAnimation);

        U4DBall *ball=U4DBall::sharedInstance();
        U4DVector3n ballPosition=ball->getAbsolutePosition();
        ballPosition.y=uPlayer->getAbsolutePosition().y;

        //compute the final velocity
        U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, ballPosition);

        //set the final y-component to zero
        finalVelocity.y=0.0;

        if(!(finalVelocity==U4DVector3n(0.0,0.0,0.0))){

            uPlayer->applyVelocity(finalVelocity, dt);
            uPlayer->setMoveDirection(finalVelocity);

        }else{
            
            uPlayer->changeState(U4DPlayerStateHalt::sharedInstance());
            
        }
        
    }

    void U4DPlayerStateJog::exit(U4DPlayer *uPlayer){
        
    }

    bool U4DPlayerStateJog::isSafeToChangeState(U4DPlayer *uPlayer){
        
        return true;
    }

    bool U4DPlayerStateJog::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
        
        switch (uMsg.msg) {
            
            case msgChaseBall:
            {
                uPlayer->changeState(U4DPlayerStateDribbling::sharedInstance());
            }
                
                
                break;
                
            default:
                break;
        }
        
        return false;
        
    }


}
