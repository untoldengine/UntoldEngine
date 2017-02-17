//
//  U4DBlendAnimation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DBlendAnimation.h"
#include "U4DAnimation.h"
#include "U4DModel.h"
#include "U4DBoneData.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    U4DBlendAnimation::U4DBlendAnimation(U4DAnimationManager *uAnimationManager){
        
        animationManager=uAnimationManager;
        
        scheduler=new U4DCallback<U4DBlendAnimation>;
        
        timer=new U4DTimer(scheduler);
    }
    
    U4DBlendAnimation::~U4DBlendAnimation(){
        
        delete scheduler;
        delete timer;
        
    }
    
    void U4DBlendAnimation::setAnimationsToBlend(){
        
        previousAnimation=animationManager->getPreviousAnimation();
        
        nextAnimation=animationManager->getNextAnimation();
        
        u4dModel=nextAnimation->u4dModel;
        
        //copy the root bone
        rootBone=u4dModel->armatureManager->rootBone;
        
        keyframe=previousAnimation->getCurrentKeyframe();
        
        interpolationTime=1.0-previousAnimation->getCurrentInterpolationTime();
        
    }
    
    void U4DBlendAnimation::playBlendedAnimation(){
        
         U4DLogger *logger=U4DLogger::sharedInstance();
        
        setAnimationsToBlend();
        
        if (nextAnimation->animationsContainer.size()>1) {
            
        
            ANIMATIONDATA animationData=previousAnimation->animationsContainer.at(0);
            
            //get the time length for initial keyframe
            float durationOfKeyframe=animationData.keyframes.at(keyframe).time;
            
            scheduler->scheduleClassWithMethodAndDelay(this, &U4DBlendAnimation::runAnimation, timer,durationOfKeyframe/previousAnimation->getFPS(), true);
    
            
        }else{
            logger->log("Error: The blended animation of animation %s and animation &s could not be started because it has no keyframes or only 1 keyframe.",previousAnimation->name.c_str(),nextAnimation->name.c_str());
        }
        
    }
    
    void U4DBlendAnimation::runAnimation(){
        
        U4DDualQuaternion finalSpaceTransform;
        
        //YOU MUST CLEAR THE U4DMODEL FINAL ANIMATION BONE MATRIX
        nextAnimation->u4dModel->armatureBoneMatrix.clear();
        
        U4DBoneData *boneChild=rootBone;
        
        ANIMATIONDATA previousAnimationData;
        ANIMATIONDATA nextAnimationData;
        
        while (boneChild!=NULL) {
            
            previousAnimationData=previousAnimation->animationsContainer.at(boneChild->index);
            nextAnimationData=nextAnimation->animationsContainer.at(boneChild->index);
            
            //compute the interpolation here
            
            U4DDualQuaternion animationFrom=previousAnimationData.keyframes.at(keyframe).animationSpaceTransform;
            U4DDualQuaternion animationTo=nextAnimationData.keyframes.at(0).animationSpaceTransform;
            
            U4DDualQuaternion animationInterpolation=animationFrom.sclerp(animationTo, interpolationTime);
            
            
            if (boneChild->isRoot()) {
                
                boneChild->animationPoseSpace=animationInterpolation;
                
            }else{
                
                
                boneChild->animationPoseSpace=animationInterpolation*boneChild->parent->animationPoseSpace;
                
            }
            
            U4DDualQuaternion finalMatrixSpace=boneChild->inverseBindPoseSpace*boneChild->animationPoseSpace;
            
            finalMatrixSpace=finalMatrixSpace*u4dModel->armatureManager->bindShapeSpace;
            
            //convert F into a 4x4 matrix
            U4DMatrix4n finalMatrixTransform=finalMatrixSpace.transformDualQuaternionToMatrix4n();
            
            //apply the MODELER animation transform-This is needed. For example, blender has a different bone-armature space than opengl
            finalMatrixTransform=nextAnimation->modelerAnimationTransform.inverse()*finalMatrixTransform*nextAnimation->modelerAnimationTransform;
            
            //F is then loaded into a buffer which will be sent to openGL buffer
            u4dModel->armatureBoneMatrix.push_back(finalMatrixTransform);
            
            boneChild=boneChild->next;
            
            
        }//end while
        
        //increment interpolation time
        if (interpolationTime>1.0) {
            
            //unschedule the timer
            scheduler->unScheduleTimer(timer);
            
            animationManager->setPlayBlendedAnimation(false);
            
            //call the manager and play next animation
            animationManager->playAnimation();
            
        }else{
            
            interpolationTime+=0.10;
            
        }
        
        
    }
}
