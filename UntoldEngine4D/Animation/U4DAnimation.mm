//
//  U4DAnimation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/9/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DAnimation.h"
#include "U4DModel.h"
#include "U4DBoneData.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
U4DAnimation::U4DAnimation(U4DModel *uModel):animationPlaying(false),keyframe(0),interpolationTime(0.0){
    
    u4dModel=uModel;
    
    //copy the root bone
    rootBone=u4dModel->armatureManager->rootBone;
    
    scheduler=new U4DCallback<U4DAnimation>;
    
    timer=new U4DTimer(scheduler);

};

U4DAnimation::~U4DAnimation(){

    delete scheduler;
    delete timer;

};


void U4DAnimation::play(){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    if (animationsContainer.size()>0) {
        
        if (animationPlaying==false) {
            
            //set interpolation time to zero
            interpolationTime=0.0;
            
            animationPlaying=true;
            
            scheduler->scheduleClassWithMethodAndDelay(this, &U4DAnimation::runAnimation, timer,(1/fps), true);
            
        }
        
    }else{
        logger->log("Error: The animation %s could not be started because it has no keyframes",name.c_str());
    }
    
}

void U4DAnimation::stop(){
    
    animationPlaying=false;
    timer->setRepeat(false);
    
}
    
void U4DAnimation::pause(){

    animationPlaying=false;
    timer->setRepeat(false);

}

bool U4DAnimation::isAnimationPlaying(){

    return animationPlaying;
}

void U4DAnimation::runAnimation(){
    
    U4DDualQuaternion finalSpaceTransform;
    
    //YOU MUST CLEAR THE U4DMODEL FINAL ANIMATION BONE MATRIX
    u4dModel->armatureBoneMatrix.clear();
    
    U4DBoneData *boneChild=rootBone;
    
    ANIMATIONDATA animationData;
   
    
    while (boneChild!=NULL) {
        
        animationData=animationsContainer.at(boneChild->index);
        
        //compute the interpolation here
        
        U4DDualQuaternion animationFrom=animationData.keyframes.at(keyframe).animationSpaceTransform;
        U4DDualQuaternion animationTo=animationData.keyframes.at(keyframe+1).animationSpaceTransform;
        
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
        finalMatrixTransform=modelerAnimationTransform.inverse()*finalMatrixTransform*modelerAnimationTransform;
        
        //F is then loaded into a buffer which will be sent to openGL buffer
        u4dModel->armatureBoneMatrix.push_back(finalMatrixTransform);
        
        boneChild=boneChild->next;
        
        
    }//end while
    
    //increment interpolation time
    if (interpolationTime>1.0) {
        
        interpolationTime=0.0;  //reset interpolation
       
        if (keyframe>=keyframeRange-2) {
            keyframe=0;
            
        }else{
            keyframe++;
        }
        
    }else{
        interpolationTime+=0.5;
    }

    
}
    
int U4DAnimation::getCurrentKeyframe(){

    return keyframe;
}

float U4DAnimation::getFPS(){

    return fps;
}

float U4DAnimation::getCurrentInterpolationTime(){
    
    return interpolationTime;
}

bool U4DAnimation::getIsUpdatingKeyframe(){

    return timer->getHasTimerExpired();
}
    

}

