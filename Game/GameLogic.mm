//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameLogic.h"

#include "U4DQuaternion.h"


void GameLogic::update(double dt){

    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    
}

void GameLogic::controllerAction(U4DEngine::U4DVector3n& uData){
    
    std::cout<<"I'm moving joystick"<<std::endl;
    
}

void GameLogic::controllerAction(std::string uData){
    
    std::cout<<"I'm pressing button"<<std::endl;
}

