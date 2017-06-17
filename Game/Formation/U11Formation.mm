//
//  U11Formation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Formation.h"
#include "U11FormationEntity.h"


U11Formation::U11Formation(){}

U11Formation::~U11Formation(){}


void U11Formation::translateAllEntitiesToOrigin(){
    
    U11FormationEntity* child=mainParent;
    
    while (child!=NULL) {
        
        child->translateToOriginPosition();
        
        child=dynamic_cast<U11FormationEntity*>(child->next);
        
    }
    
}

U11FormationEntity *U11Formation::assignFormationEntity(){
    
    U11FormationEntity* child=mainParent;
    child=dynamic_cast<U11FormationEntity*>(child->next);
    
    while (child!=NULL) {
        
        if(child->isAssigned()==false){
            
            child->setAssigned(true);
            
            break;
            
        }else{
            
            child=dynamic_cast<U11FormationEntity*>(child->next);
        }
        
    }
    
    return child;
    
}

void U11Formation::translateFormation(U4DEngine::U4DVector3n &uPosition){
    
//    U4DEngine::U4DPoint3n positionPoint=uPosition.toPoint();
//    
//    if (formationAABB.isPointInsideAABB(positionPoint)) {
//        
//        mainParent->translateTo(uPosition);
//        
//    }
    
}
