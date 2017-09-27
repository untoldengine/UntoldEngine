//
//  U11PlayerIndicator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/31/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerIndicator.h"
#include "U11Team.h"
#include "U11Player.h"

U11PlayerIndicator::U11PlayerIndicator(U11Team *uTeam):team(uTeam){
    
}

U11PlayerIndicator::~U11PlayerIndicator(){
    
}

void U11PlayerIndicator::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        setEntityType(U4DEngine::MODELNOSHADOWS);
    
        U4DEngine::U4DVector3n viewDirectionVector(0,0,-1);
        
        setEntityForwardVector(viewDirectionVector);
        
        loadRenderingInformation();
        
    }
}

void U11PlayerIndicator::update(double dt){
    
    U11Player* player=team->getIndicatorForPlayer();
    
    if (player!=nullptr) {
        
        U4DEngine::U4DVector3n heading=player->getPlayerHeading();
        
        heading.x*=fieldLength;
        heading.z*=fieldWidth;
        heading.y=player->getAbsolutePosition().y;
        
        viewInDirection(heading);
        
        U4DEngine::U4DVector3n position=player->getAbsolutePosition();
        
        translateTo(position);
        
    }
    
}
