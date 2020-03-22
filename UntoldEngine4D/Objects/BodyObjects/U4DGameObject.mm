//
//  U4DGameObject.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DGameObject.h"
#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "U4DResourceLoader.h"

namespace U4DEngine {
    
    U4DGameObject::U4DGameObject(){
     
    }

    U4DGameObject::~U4DGameObject(){
    
    }
    
    U4DGameObject::U4DGameObject(const U4DGameObject& value){
    
    }
    
    U4DGameObject& U4DGameObject::operator=(const U4DGameObject& value){
        
        return *this;
    
    }

    bool U4DGameObject::loadModel(const char* uModelName){
        
        U4DEngine::U4DResourceLoader *loader=U4DEngine::U4DResourceLoader::sharedInstance();
        
        if (loader->loadAssetToMesh(this, uModelName)) {
            
           //init the culling bounding volume
           initCullingBoundingVolume();
           
           return true;
            
        }
        
        return false;
    }

    bool U4DGameObject::loadAnimationToModel(U4DAnimation *uAnimation, const char* uAnimationName){
        
        U4DEngine::U4DResourceLoader *loader=U4DEngine::U4DResourceLoader::sharedInstance();
        
        if (loader->loadAnimationToMesh(uAnimation,uAnimationName)) {
            
           
           return true;
            
        }
        
        return false;
        
    }
    
    bool U4DGameObject::getBoneRestPose(std::string uBoneName, U4DMatrix4n &uBoneRestPoseMatrix){

        U4DBoneData *rootBone=armatureManager->rootBone;
        
        //check if rootbone exist
        if(rootBone!=nullptr){
            
            //get the bone rest pose space
            U4DDualQuaternion boneRestPoseSpace=rootBone->searchChildrenBone(uBoneName)->restAbsolutePoseSpace;
            
            //get the position of the bone
            U4DQuaternion bonePureQuaternion=boneRestPoseSpace.getPureQuaternionPart();
            
            U4DVector3n bonePosition=bonePureQuaternion.v;
            
            //get the final matrix of the bone in rest pose
            uBoneRestPoseMatrix=rootBone->searchChildrenBone(uBoneName)->finalSpaceMatrix;
            
            //flip the y and z coordinates to compensate for the different coordinates systems between Blender and the Untold Engine
            //Note that I had to use the location of the rest pose space and use it as the final space matrix location
            uBoneRestPoseMatrix.matrixData[12]=bonePosition.x;
            uBoneRestPoseMatrix.matrixData[13]=bonePosition.z;
            uBoneRestPoseMatrix.matrixData[14]=bonePosition.y;
            
            return true;
        
        }
        
        return false;
        
    }
    
    bool U4DGameObject::getBoneAnimationPose(std::string uBoneName, U4DAnimation *uAnimation, U4DMatrix4n &uBoneAnimationPoseMatrix){
        
    
        U4DBoneData *rootBone=armatureManager->rootBone;
        
        //check if rootbone exist and animation is currently being played
        if (rootBone!=nullptr && uAnimation->getAnimationIsPlaying()==true) {
            
            //get the bone animation pose space
            U4DDualQuaternion boneAnimationPoseSpace=rootBone->searchChildrenBone(uBoneName)->animationPoseSpace;
            
            //get the position of the bone
            U4DQuaternion bonePureQuaternion=boneAnimationPoseSpace.getPureQuaternionPart();
            
            U4DVector3n bonePosition=bonePureQuaternion.v;
            
            //get the final matrix of the bone in animation pose
            uBoneAnimationPoseMatrix=rootBone->searchChildrenBone(uBoneName)->finalSpaceMatrix;
            
            //flip the y and z coordinates to compensate for the different coordinates systems between Blender and the Untold Engine
            //Note that I had to use the location of the animation pose space and use it as the final space matrix location
            uBoneAnimationPoseMatrix.matrixData[12]=bonePosition.x;
            uBoneAnimationPoseMatrix.matrixData[13]=bonePosition.z;
            uBoneAnimationPoseMatrix.matrixData[14]=bonePosition.y;
            
            return true;
        
        }
        
        return false;
        
    }
    
    
}





