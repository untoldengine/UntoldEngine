//
//  U4DBVHCollisionInterface.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DBVHCollision.h"
#include "U4DBVHTree.h"
#include "U4DDynamicModel.h"

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
    
    bool U4DBVHCollision::shouldModelsCollide(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2){
        
        signed int model1GroupIndex=uModel1->getCollisionFilterGroupIndex();
        signed int model2GroupIndex=uModel2->getCollisionFilterGroupIndex();
        
        //if both groupIndex values are the same and positive, collide
        if ((model1GroupIndex>0 && model2GroupIndex>0) && (model1GroupIndex==model2GroupIndex)){
            
            return true;
            
        //if both groupIndex values are the same and negative, don't collide
        }else if((model1GroupIndex<0 && model2GroupIndex<0) && (model1GroupIndex==model2GroupIndex)){
            
            return false;
            
        //if either model has a groupIndex of zero, use the category/mask rules
        }else if ((model1GroupIndex==0 || model2GroupIndex==0)){
            
            return (uModel1->getCollisionFilterCategory() & uModel2->getCollisionFilterMask())!=0 && ((uModel2->getCollisionFilterCategory() & uModel1->getCollisionFilterMask())!=0);
        
        //if both models groupindex are non-zero but different, use the category/mask rules
        }else if ((model1GroupIndex!=0 && model2GroupIndex!=0) && (model1GroupIndex!=model2GroupIndex)){
            
            return (uModel1->getCollisionFilterCategory() & uModel2->getCollisionFilterMask())!=0 && ((uModel2->getCollisionFilterCategory() & uModel1->getCollisionFilterMask())!=0);

        }
        
        return true;
        
    }
    
}
