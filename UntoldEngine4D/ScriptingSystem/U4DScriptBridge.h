//
//  U4DScriptBridge.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBridge_hpp
#define U4DScriptBridge_hpp

#include <stdio.h>
#include <iostream>
#include <list>
#include "U4DWorld.h"


namespace U4DEngine {

    class U4DScriptBridge {
        
    private:
        
        U4DWorld *world;
        static U4DScriptBridge *instance;
        
    protected:
        
        U4DScriptBridge();
        
        ~U4DScriptBridge();
        
    public:
        
        static U4DScriptBridge *sharedInstance();
        
        std::string loadModel(std::string uAssetName);
        
        std::string loadModel(std::string uAssetName, std::string uPipelineName);
        
        void addChild(std::string uEntityName,std::string uParentName);
        
        void removeChild(std::string uEntityName);
        
        //Transformation
        void translateTo(std::string uEntityName, U4DVector3n uPosition);
        
        void translateBy(std::string uEntityName,U4DVector3n uPosition);
        
        void rotateTo(std::string uEntityName,U4DVector3n uOrientation);
        
        void rotateBy(std::string uEntityName,U4DVector3n uOrientation);
        
        void rotateBy(std::string uEntityName,float uAngle, U4DVector3n uAxis);
        
        U4DVector3n getAbsolutePosition(std::string uEntityName);
        
        U4DVector3n getAbsoluteOrientation(std::string uEntityName);
        
        U4DVector3n getViewInDirection(std::string uEntityName);
        
        void setViewInDirection(std::string uEntityName, U4DVector3n uDirection);
        
        void setEntityForwardVector(std::string uEntityName, U4DVector3n uViewDirection);
        
        U4DVector3n getModelDimensions(std::string uEntityName);
        
        //Physics
        void initPhysics(std::string uEntityName);
        
        void deinitPhysics(std::string uEntityName);
        
        void setGravity(std::string uEntityName, U4DVector3n uGravity);
        
        //void applyVelocity(std::string uEntityName, U4DVector3n uVelocity, float dt);
        
        void initMass(std::string uEntityName, float uMass);
        
        void initAsPlatform(std::string uEntityName, bool uValue);
        
        void resumeCollisionBehavior(std::string uEntityName);
        
        void pauseCollisionBehavior(std::string uEntityName);
        
        float getMass(std::string uEntityName);
        
        void addForce(std::string uEntityName,U4DVector3n uForce);
        
        void addMoment(std::string uEntityName,U4DVector3n uMoment);
        
        void setVelocity(std::string uEntityName, U4DVector3n uVelocity);
        
        void setAngularVelocity(std::string uEntityName, U4DVector3n uVelocity);
        
        U4DVector3n getVelocity(std::string uEntityName);
        
        void setAwake(std::string uEntityName, bool uValue);
        
        //collision filters, masks, etc
        void setCollisionFilterCategory(std::string uEntityName, int uCategory);
        
        void setCollisionFilterMask(std::string uEntityName, int uMask);
        
        void setIsCollisionSensor(std::string uEntityName, bool uValue);
        
        void setCollidingTag(std::string uEntityName, std::string uCollidingTag);
        
        bool getModelHasCollided(std::string uEntityName);
        
        std::list<std::string> getCollisionListTags(std::string uEntityName);
        
        //Animations
        void initAnimations(std::string uEntityName, std::list<std::string> uAnimationList);
        
        void deinitAnimations(std::string uEntityName);
        
        void playAnimation(std::string uEntityName, std::string uAnimationName);
        
        void stopAnimation(std::string uEntityName);
        
        void setEntityToArmatureBoneSpace(std::string uEntityName,std::string uActorName,std::string uBoneName);
        
        void setEntityToAnimationBoneSpace(std::string uEntityName,std::string uActorName,std::string uAnimationName,std::string uBoneName);
        
        void setPlayContinuousLoop(std::string uEntityName, std::string uAnimationName, bool uValue);
        
        bool getAnimationIsPlaying(std::string uEntityName, std::string uAnimationName);
        
        int getCurrentKeyframe(std::string uEntityName, std::string uAnimationName);
        
        //camera perspective
        void setCameraAsThirdPerson(std::string uEntityName, U4DVector3n uOffset);
        
        void setCameraAsFirstPerson(std::string uEntityName, U4DVector3n uOffset);
        
        void setCameraAsBasicFollow(std::string uEntityName, U4DVector3n uOffset);
        
        void setCameraAsBasicFollowWithBoxTracking(std::string uEntityName, U4DVector3n uOffset, U4DVector3n uMinPoint,U4DVector3n uMaxPoint);
        
        //AI Steering
        
        U4DVector3n seek(std::string uEntityName,U4DVector3n uTargetPosition);
        
        U4DVector3n arrive(std::string uEntityName,U4DVector3n uTargetPosition);
        
        U4DVector3n arrive(std::string uEntityName,U4DVector3n uTargetPosition, float uMaxSpeed, float uTargetRadius, float uSlowRadius);
        
        U4DVector3n pursuit(std::string uPursuerName,std::string uEvaderName);
        
        U4DVector3n pursuit(std::string uPursuerName,std::string uEvaderName, float uMaxSpeed);
        
        void pauseScene();
        
        void playScene();
        
        void anchorMouse(bool uValue);
        
    };

}


#endif /* U4DScriptBridge_hpp */
