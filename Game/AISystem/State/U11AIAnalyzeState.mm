//
//  U11AnalyzeState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AIAnalyzeState.h"

U11AIAnalyzeState* U11AIAnalyzeState::instance=0;

U11AIAnalyzeState::U11AIAnalyzeState(){
    
}

U11AIAnalyzeState::~U11AIAnalyzeState(){
    
}

U11AIAnalyzeState* U11AIAnalyzeState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11AIAnalyzeState();
    }
    
    return instance;
    
}

void U11AIAnalyzeState::enter(U11AIStrategyInterface *uAIStrategy){
    
    //get the triangle mid point
    
    //get the number of players threatening the triangle
}

void U11AIAnalyzeState::execute(U11AIStrategyInterface *uAIStrategy, double dt){
    
    //if number of players inside the triangle more than 1, then clear the ball
    
    //compute safest player to pass ball to
}

void U11AIAnalyzeState::exit(U11AIStrategyInterface *uAIStrategy){
    
}

