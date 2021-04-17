//
//  PlayerStatePass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStatePass.h"

#include "Foot.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateIntercept.h"
#include "PlayAnalyzer.h"
#include "MessageDispatcher.h"
#include "Team.h"


PlayerStatePass* PlayerStatePass::instance=0;

PlayerStatePass::PlayerStatePass(){
    name="pass";
}

PlayerStatePass::~PlayerStatePass(){
    
}

PlayerStatePass* PlayerStatePass::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStatePass();
    }
    
    return instance;
    
}

void PlayerStatePass::enter(Player *uPlayer){
    
    //play the pass animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    
    
}

void PlayerStatePass::execute(Player *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    //apply a force
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    
    
    if (currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()>1) {

        uPlayer->rightFoot->setKickBallParameters(passBallSpeed,uPlayer->dribblingDirection);
        
        uPlayer->rightFoot->resumeCollisionBehavior();
        
    }
    
    if (currentAnimation->getAnimationIsPlaying()==false) {
        
        uPlayer->changeState(PlayerStateIdle::sharedInstance());
    
    }
    
}

void PlayerStatePass::exit(Player *uPlayer){
    
    uPlayer->passBall=false;
    
    //get closest player to intersect the ball
    PlayAnalyzer *playAnalyzer=PlayAnalyzer::sharedInstance();

    Player *teammate=playAnalyzer->closestTeammateToIntersectBall(uPlayer);

    //send message to player
    MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

    messageDispatcher->sendMessage(0.0, uPlayer, teammate, msgInterceptBall);
    
    Team *team=uPlayer->getTeam();
    team->setControllingPlayer(teammate);
}

bool PlayerStatePass::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStatePass::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
            
        default:
            break;
    }
    
    return false;
    
}
