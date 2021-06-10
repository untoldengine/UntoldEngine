//
//  U4DBVHCollisionInterface.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#include "U4DBVHCollision.h"
#include "U4DDynamicAction.h"

namespace U4DEngine {
    
    U4DBVHCollision::U4DBVHCollision(){
        
    }
    
    U4DBVHCollision::~U4DBVHCollision(){
        
    }
    
    bool U4DBVHCollision::collisionBetweenTreeVolume(U4DBVHNode<U4DDynamicAction> *uTreeLeftNode, U4DBVHNode<U4DDynamicAction> *uTreeRightNode){
        return uTreeLeftNode->getAABBVolume()->intersectionWithVolume(uTreeRightNode->getAABBVolume());
    }
    
    bool U4DBVHCollision::descendTreeRule(U4DBVHNode<U4DDynamicAction> *uTreeLeftNode, U4DBVHNode<U4DDynamicAction> *uTreeRightNode){
        
        bool value=false;
        
        if (uTreeLeftNode->getFirstChild()!=NULL) {
            return value=true;
        }
        
        return value;
        
    }
    
    bool U4DBVHCollision::shouldModelsCollide(U4DDynamicAction* uAction1, U4DDynamicAction* uAction2){
        
        signed int model1GroupIndex=uAction1->getCollisionFilterGroupIndex();
        signed int model2GroupIndex=uAction2->getCollisionFilterGroupIndex();
        
        //if both groupIndex values are the same and positive, collide
        if ((model1GroupIndex>0 && model2GroupIndex>0) && (model1GroupIndex==model2GroupIndex)){
            
            return true;
            
        //if both groupIndex values are the same and negative, don't collide
        }else if((model1GroupIndex<0 && model2GroupIndex<0) && (model1GroupIndex==model2GroupIndex)){
            
            return false;
            
        //if either model has a groupIndex of zero, use the category/mask rules
        }else if ((model1GroupIndex==0 || model2GroupIndex==0)){
            
            return (uAction1->getCollisionFilterCategory() & uAction2->getCollisionFilterMask())!=0 && ((uAction2->getCollisionFilterCategory() & uAction1->getCollisionFilterMask())!=0);
        
        //if both models groupindex are non-zero but different, use the category/mask rules
        }else if ((model1GroupIndex!=0 && model2GroupIndex!=0) && (model1GroupIndex!=model2GroupIndex)){
            
            return (uAction1->getCollisionFilterCategory() & uAction2->getCollisionFilterMask())!=0 && ((uAction2->getCollisionFilterCategory() & uAction1->getCollisionFilterMask())!=0);

        }
        
        return true;
        
    }
    
}
