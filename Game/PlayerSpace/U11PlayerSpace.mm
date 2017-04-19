//
//  U11PlayerSpace.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerSpace.h"

U11PlayerSpace::U11PlayerSpace(){
    
}

U11PlayerSpace::~U11PlayerSpace(){
    
}

void U11PlayerSpace::setFormationSpace(U4DEngine::U4DAABB &uFormationSpace){
    
    formationSpace=uFormationSpace;
    
}

void U11PlayerSpace::setHomePosition(U4DEngine::U4DPoint3n &uHomePosition){
    
    homePosition=uHomePosition;
}

void U11PlayerSpace::setFormationPosition(U4DEngine::U4DPoint3n &uFormationPosition){
    
    formationPosition=uFormationPosition;
    
}

U4DEngine::U4DPoint3n U11PlayerSpace::getFormationPosition(){
    
    return formationPosition;
    
}

U4DEngine::U4DPoint3n U11PlayerSpace::getHomePosition(){
    
    return homePosition;
    
}

U4DEngine::U4DAABB U11PlayerSpace::getFormationSpace(){
    
    return formationSpace;
}
