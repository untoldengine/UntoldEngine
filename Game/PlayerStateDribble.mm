//
//  PlayerStateDribble.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateDribble.h"
#include "Foot.h"
#include "Team.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"

PlayerStateDribble* PlayerStateDribble::instance=0;

PlayerStateDribble::PlayerStateDribble(){
    
}

PlayerStateDribble::~PlayerStateDribble(){
    
}

PlayerStateDribble* PlayerStateDribble::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateDribble();
    }
    
    return instance;
    
}

void PlayerStateDribble::enter(Player *uPlayer){
    
    //play the running animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //set as the controlling Player
//    Team *team=uPlayer->getTeam();
//    team->setControllingPlayer(uPlayer);
    
}

void PlayerStateDribble::execute(Player *uPlayer, double dt){
    
    //play the dribble animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    uPlayer->dribbleBall=false;
    
    //compute the final velocity
    U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
    
    //change the y-position of the ball to be the same as the player
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, ballPosition);
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }else{
        
        if(uPlayer->passBall==true){

            uPlayer->changeState(PlayerStatePass::sharedInstance());

        }else if(uPlayer->shootBall==true){

            uPlayer->changeState(PlayerStateShoot::sharedInstance());

        }
        else if(uPlayer->haltBall==true){

            uPlayer->changeState(PlayerStateHalt::sharedInstance());

        }
         
    }
    
    if (currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()>6) {
        
        uPlayer->rightFoot->setKickBallParameters(dribbleBallSpeed,uPlayer->dribblingDirection);
        
        uPlayer->rightFoot->resumeCollisionBehavior();
    }
}

void PlayerStateDribble::exit(Player *uPlayer){
    
}

bool PlayerStateDribble::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateDribble::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
            
        default:
            break;
    }
    
    return false;
    
}
