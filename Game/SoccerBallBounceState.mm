//
//  SoccerBallBounceState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerBallBounceState.h"
#include "SoccerBall.h"

SoccerBallBounceState* SoccerBallBounceState::instance=0;

SoccerBallBounceState::SoccerBallBounceState(){
    
}

SoccerBallBounceState::~SoccerBallBounceState(){
    
}

SoccerBallBounceState* SoccerBallBounceState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerBallBounceState();
    }
    
    return instance;
    
}

void SoccerBallBounceState::enter(SoccerBall *uBall){
    
    U4DEngine::U4DVector2n dragCoefficients(2.0,2.0);
    uBall->setDragCoefficient(dragCoefficients);
    
}

void SoccerBallBounceState::execute(SoccerBall *uBall, double dt){
    
    
}

void SoccerBallBounceState::exit(SoccerBall *uBall){
    
}

bool SoccerBallBounceState::isSafeToChangeState(SoccerBall *uBall){
    
    return true;
}
