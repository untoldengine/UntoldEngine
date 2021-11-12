//
//  PlayerStateDribbling.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateDribbling.h"
#include "U4DGameConfigs.h"
#include "Ball.h"
#include "PlayerStateShooting.h"

PlayerStateDribbling* PlayerStateDribbling::instance=0;

PlayerStateDribbling::PlayerStateDribbling(){
    name="dribbling";
}

PlayerStateDribbling::~PlayerStateDribbling(){
    
}

PlayerStateDribbling* PlayerStateDribbling::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateDribbling();
    }
    
    return instance;
    
}

void PlayerStateDribbling::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveMaxSpeed"));
    uPlayer->arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("arriveStopRadius"));
    uPlayer->arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("arriveSlowRadius"));
    
}

void PlayerStateDribbling::execute(Player *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->runningAnimation);
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();

    
    Ball *ball=Ball::sharedInstance();

    U4DEngine::U4DVector3n ballPos=ball->getAbsolutePosition();

    ballPos.y=uPlayer->getAbsolutePosition().y;


    

    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, ballPos);

    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);

    }else{

        if(uPlayer->shootBall==true){

            uPlayer->changeState(PlayerStateShooting::sharedInstance());

        }

    }

    uPlayer->foot->kineticAction->resumeCollisionBehavior();

    uPlayer->foot->setKickBallParameters(gameConfigs->getParameterForKey("dribblingBallSpeed"), uPlayer->dribblingDirection); 
    
}

void PlayerStateDribbling::exit(Player *uPlayer){
    
}

bool PlayerStateDribbling::isSafeToChangeState(Player *uPlayer){
    
    return true;
}


