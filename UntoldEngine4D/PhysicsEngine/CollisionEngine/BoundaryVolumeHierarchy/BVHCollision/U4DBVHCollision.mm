//
//  U4DBVHCollisionInterface.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DBVHCollision.h"
#include "U4DBVHTree.h"

namespace U4DEngine {
    
    U4DBVHCollision::U4DBVHCollision(){
        
    }
    
    U4DBVHCollision::~U4DBVHCollision(){
        
    }
    
    bool U4DBVHCollision::collisionBetweenTreeVolume(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){
        return uTreeLeftNode->getAABBVolume()->intersectionWithVolume(uTreeRightNode->getAABBVolume());
    }
    
    bool U4DBVHCollision::descendTreeRule(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){
        
        bool value=false;
        
        if (uTreeLeftNode->getFirstChild()!=NULL) {
            return value=true;
        }
        
        return value;
        
    }
    
}