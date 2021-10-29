//
//  U4DScriptBridge.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBridge.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DVector3n.h"
#include "U4DModel.h"
#include "U4DDynamicAction.h"
#include "U4DAnimationManager.h"
#include "U4DAnimation.h"
#include "U4DSeek.h"
#include "U4DArrive.h"
#include "U4DPursuit.h"

#include "U4DCamera.h"
#include "U4DCameraInterface.h"
#include "U4DCameraFirstPerson.h"
#include "U4DCameraThirdPerson.h"
#include "U4DCameraBasicFollow.h"

namespace U4DEngine {

U4DScriptBridge* U4DScriptBridge::instance=0;

U4DScriptBridge* U4DScriptBridge::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptBridge();
    }

    return instance;
}

U4DScriptBridge::U4DScriptBridge(){
 
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    world=scene->getGameWorld();
    
}

U4DScriptBridge::~U4DScriptBridge(){
    
}

std::string U4DScriptBridge::loadModel(std::string uAssetName){
    
    U4DModel *model= new U4DModel();

    if (model->loadModel(uAssetName.c_str())) {
        
        model->loadRenderingInformation();
        
        world->addChild(model);
        
        return model->getName();
    }
    
    return "ERROR";
    
}

void U4DScriptBridge::addChild(std::string uEntityName,std::string uParentName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    U4DEntity *entityParent=world->searchChild(uParentName);
    
    if (entity!=nullptr && entityParent!=nullptr) {
        
        //remove child from current parent
        U4DEntity *currentParent=entity->getParent();
        if (currentParent!=nullptr) {
            currentParent->removeChild(entity);
        }
        
        //add child to new parent
        entityParent->addChild(entity);
        
    }
    
}

void U4DScriptBridge::removeChild(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        //remove child from current parent
        U4DEntity *currentParent=entity->getParent();
        if (currentParent!=nullptr) {
            currentParent->removeChild(entity);
        }
        
        
    }
}

void U4DScriptBridge::translateTo(std::string uEntityName, U4DVector3n uPosition){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        entity->translateTo(uPosition);
        
    }
    
}

void U4DScriptBridge::translateBy(std::string uEntityName,U4DVector3n uPosition){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        entity->translateBy(uPosition); 
        
    }
}

void U4DScriptBridge::rotateTo(std::string uEntityName,U4DVector3n uOrientation){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        entity->rotateTo(uOrientation.x,uOrientation.y,uOrientation.z);
        
    }
}

void U4DScriptBridge::rotateBy(std::string uEntityName,U4DVector3n uOrientation){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        entity->rotateBy(uOrientation.x,uOrientation.y,uOrientation.z);
        
    }
}

void U4DScriptBridge::rotateBy(std::string uEntityName,float uAngle, U4DVector3n uAxis){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        U4DQuaternion newOrientation(uAngle,uAxis);
        U4DQuaternion currentOrientation=entity->getAbsoluteSpaceOrientation();
        U4DQuaternion p=currentOrientation.slerp(newOrientation, 1.0);
        
        entity->rotateBy(p);
        
    }
}

U4DVector3n U4DScriptBridge::getAbsolutePosition(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    U4DVector3n v;
    
    if (entity!=nullptr) {
        
        v=entity->getAbsolutePosition();
        
    }
    
    return v;
}

U4DVector3n U4DScriptBridge::getAbsoluteOrientation(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    U4DVector3n v;
    
    if (entity!=nullptr) {
        
        v=entity->getAbsoluteOrientation();
        
    }
    
    return v;
}

U4DVector3n U4DScriptBridge::getViewInDirection(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    U4DVector3n v;
    
    if (entity!=nullptr) {
        
        v=entity->getViewInDirection();
        
    }
    
    return v;
}

void U4DScriptBridge::setViewInDirection(std::string uEntityName, U4DVector3n uDirection){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        uDirection.normalize();
        
        //Get entity forward vector for the player
        U4DEngine::U4DVector3n v=entity->getViewInDirection();

        v.normalize();
        
        //set an up-vector
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);

        U4DEngine::U4DMatrix3n m=entity->getAbsoluteMatrixOrientation();

        //transform the up vector
        upVector=m*upVector;

        U4DEngine::U4DVector3n posDir=v.cross(upVector);

        //Get the angle between the analog joystick direction and the view direction
        float angle=v.angle(uDirection);
        
        //if the dot product between the joystick-direction and the positive direction is less than zero, flip the angle
        if(uDirection.dot(posDir)>0.0){
            angle*=-1.0;
        }
        
        //create a quaternion between the angle and the upvector
        U4DEngine::U4DQuaternion newOrientation(angle,upVector);

        //Get current orientation of the player
        U4DEngine::U4DQuaternion modelOrientation=entity->getAbsoluteSpaceOrientation();

        //create slerp interpolation
        U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation, 1.0);

        //rotate the character
        entity->rotateBy(p);
        
    }
    
}

void U4DScriptBridge::setEntityForwardVector(std::string uEntityName, U4DVector3n uViewDirection){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        uViewDirection.normalize();
        
        entity->setEntityForwardVector(uViewDirection);
    }
    
}

void U4DScriptBridge::initPhysics(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    
    if (entity!=nullptr) {
        
        //test if the kinetic action already exist for the model
        U4DDynamicAction *tempKineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        if (tempKineticAction==nullptr){
            
            //U4DModel *model=dynamic_cast<U4DModel*>(entity);
            U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
            
            //enable kinetics and collision detection
            U4DDynamicAction *kineticAction=new U4DDynamicAction(model);
            
            kineticAction->enableKineticsBehavior();
            kineticAction->enableCollisionBehavior();
            
        }
        
    }
}

void U4DScriptBridge::deinitPhysics(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        if(kineticAction!=nullptr){
            
            delete kineticAction;
            
        }
        
        
    }
    
}

void U4DScriptBridge::applyVelocity(std::string uEntityName, U4DVector3n uVelocity, float dt){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        if(kineticAction!=nullptr){
                
            kineticAction->applyVelocity(uVelocity, dt);
        }
        
        
    }
}

void U4DScriptBridge::setGravity(std::string uEntityName, U4DVector3n uGravity){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        if(kineticAction!=nullptr){
            
            kineticAction->setGravity(uGravity);
        }
        
        
    }
}

void U4DScriptBridge::setCollisionFilterCategory(std::string uEntityName, int uCategory){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
        
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        kineticAction->setCollisionFilterCategory(uCategory);
        
    }
}

void U4DScriptBridge::setCollisionFilterMask(std::string uEntityName, int uMask){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
        
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        kineticAction->setCollisionFilterMask(uMask);
    }
}

void U4DScriptBridge::setIsCollisionSensor(std::string uEntityName, bool uValue){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
        
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        kineticAction->setIsCollisionSensor(uValue);
        
    }
}

void U4DScriptBridge::setCollidingTag(std::string uEntityName, std::string uCollidingTag){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
     
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        kineticAction->setCollidingTag(uCollidingTag);
        
    }
}

bool U4DScriptBridge::getModelHasCollided(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
     
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        return kineticAction->getModelHasCollided();
    }
    
    return false;
}

std::list<std::string> U4DScriptBridge::getCollisionListTags(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    std::list<std::string> collisionListTags;
    
    if (entity!=nullptr ) {
     
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        for(auto n:kineticAction->getCollisionList()){
            collisionListTags.push_back(n->getCollidingTag());
        }
    }
    
    return collisionListTags;
}


void U4DScriptBridge::initAnimations(std::string uEntityName, std::list<std::string> uAnimationList){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
        
        //test if a animation manager already exist for the model
        U4DAnimationManager *tempAnimManager=reinterpret_cast<U4DAnimationManager*>(entity->pAnimationManager);
        
        if (tempAnimManager==nullptr) {
            
            U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
            U4DAnimationManager *animationManager=new U4DAnimationManager(model);
            
            animationManager->loadAnimationToDictionary(uAnimationList);
            
        }
        
        
    }
}

void U4DScriptBridge::deinitAnimations(std::string uEntityName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr) {
        
        U4DAnimationManager *animationManager=reinterpret_cast<U4DAnimationManager*>(entity->pAnimationManager);
        
        if (animationManager!=nullptr) {
            
            delete animationManager;
            
        }
        
    }
}

void U4DScriptBridge::playAnimation(std::string uEntityName, std::string uAnimationName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
        
        //test if a animation manager already exist for the model
        U4DAnimationManager *animationManager=reinterpret_cast<U4DAnimationManager*>(entity->pAnimationManager);
        
        if (animationManager!=nullptr) {
            
            //retrieve animation
            U4DAnimation *animation=animationManager->getAnimationFromDictionary(uAnimationName);
            
            if (animation!=nullptr) {
                animationManager->removeCurrentPlayingAnimation();
                animationManager->setAnimationToPlay(animation);
                animationManager->playAnimation();
            }
        }
        
        
    }
}

void U4DScriptBridge::stopAnimation(std::string uEntityName, std::string uAnimationName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    if (entity!=nullptr ) {
        
        //test if a animation manager already exist for the model
        U4DAnimationManager *animationManager=reinterpret_cast<U4DAnimationManager*>(entity->pAnimationManager);
        
        if (animationManager!=nullptr) {
            
            animationManager->stopAnimation();
            
        }
        
        
    }
}

void U4DScriptBridge::setEntityToArmatureBoneSpace(std::string uEntityName,std::string uActorName,std::string uBoneName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    U4DEntity *actor=world->searchChild(uActorName);
    
    if (entity!=nullptr && actor!=nullptr) {
        
        //declare the matrix for the entity space
        U4DMatrix4n m;
        
        U4DModel *modelEntity=reinterpret_cast<U4DModel*>(entity->pModel);
        U4DModel *modelActor=reinterpret_cast<U4DModel*>(actor->pModel);
        
        //get the bone rest pose space
        if (modelActor->getBoneRestPose(uBoneName, m)) {
            
            //apply space to gun
            modelEntity->setLocalSpace(m);
        }
        
    }
}

void U4DScriptBridge::setEntityToAnimationBoneSpace(std::string uEntityName,std::string uActorName,std::string uAnimationName,std::string uBoneName){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    U4DEntity *actor=world->searchChild(uActorName);
    
    if (entity!=nullptr && actor!=nullptr) {
        
        //declare the matrix for the entity space
        U4DMatrix4n m;
        
        U4DModel *modelEntity=reinterpret_cast<U4DModel*>(entity->pModel);
        U4DModel *modelActor=reinterpret_cast<U4DModel*>(actor->pModel);
        
        U4DAnimationManager *animationManager=reinterpret_cast<U4DAnimationManager*>(actor->pAnimationManager);
        
        if (animationManager!=nullptr) {
            
            //retrieve animation
            U4DAnimation *animation=animationManager->getAnimationFromDictionary(uAnimationName);
            
            if (animation!=nullptr) {
                
                if(modelActor->getBoneAnimationPose(uBoneName, animation, m)){
                    modelEntity->setLocalSpace(m);
                }
                
            }
            
        }
        
    }
}

U4DVector3n U4DScriptBridge::seek(std::string uEntityName,U4DVector3n uTargetPosition){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    U4DSeek seekBehavior;
    U4DVector3n finalVelocity;
    
    if (entity!=nullptr) {
        
        //get the dynamic action for the model
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        if (kineticAction!=nullptr) {
            
            finalVelocity=seekBehavior.getSteering(kineticAction, uTargetPosition);
            
        }
        
    }
    
    return finalVelocity;
    
}

U4DVector3n U4DScriptBridge::arrive(std::string uEntityName,U4DVector3n uTargetPosition){
    
    U4DEntity *entity=world->searchChild(uEntityName);
    
    U4DArrive arriveBehavior;
    U4DVector3n finalVelocity;
    
    if (entity!=nullptr) {
        
        //get the dynamic action for the model
        U4DDynamicAction *kineticAction=reinterpret_cast<U4DDynamicAction*>(entity->pDynamicAction);
        
        if (kineticAction!=nullptr) {
            
            finalVelocity=arriveBehavior.getSteering(kineticAction, uTargetPosition);
            
        }
        
    }
    
    return finalVelocity;
}

U4DVector3n U4DScriptBridge::pursuit(std::string uPursuerName,std::string uEvaderName){
    
    U4DEntity *pursuerEntity=world->searchChild(uPursuerName);
    U4DEntity *evaderEntity=world->searchChild(uEvaderName);

    U4DPursuit pursuitBehavior;
    U4DVector3n finalVelocity;
    
    if (pursuerEntity!=nullptr && evaderEntity!=nullptr) {
        
        //get the dynamic action for the model
        U4DDynamicAction *pursuerKineticAction=reinterpret_cast<U4DDynamicAction*>(pursuerEntity->pDynamicAction);
        
        U4DDynamicAction *evaderKineticAction=reinterpret_cast<U4DDynamicAction*>(evaderEntity->pDynamicAction);
        
        
        if (pursuerKineticAction!=nullptr && evaderKineticAction) {
            
            finalVelocity=pursuitBehavior.getSteering(pursuerKineticAction,evaderKineticAction);
            
        }
        
    }
    
    return finalVelocity;
    
}

    void U4DScriptBridge::setCameraAsThirdPerson(std::string uEntityName, U4DVector3n uOffset){
        
        U4DEntity *entity=world->searchChild(uEntityName);
        
        if (entity!=nullptr ) {
            
            U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
            
            //Instantiate the camera
            U4DCamera *camera=U4DCamera::sharedInstance();
            
            //Instantiate the camera interface and the type of camera you desire
            U4DCameraInterface *cameraThirdPerson=U4DCameraThirdPerson::sharedInstance();
            
            //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
            cameraThirdPerson->setParameters(model,uOffset.x,uOffset.y,uOffset.z);
            
            //Line 3. set the camera behavior
            camera->setCameraBehavior(cameraThirdPerson);
            
        }
        
    }

    void U4DScriptBridge::setCameraAsFirstPerson(std::string uEntityName, U4DVector3n uOffset){
        
        U4DEntity *entity=world->searchChild(uEntityName);
        
        if (entity!=nullptr ) {
            
            U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
            
            //Instantiate the camera
            U4DCamera *camera=U4DCamera::sharedInstance();
            
            //Instantiate the camera interface and the type of camera you desire
            U4DCameraInterface *cameraFirstPerson=U4DCameraFirstPerson::sharedInstance();
            
            //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
            
            cameraFirstPerson->setParameters(model,uOffset.x,uOffset.y,uOffset.z);
            
            //set the camera behavior
            
            camera->setCameraBehavior(cameraFirstPerson);
        
        }
    }

    void U4DScriptBridge::setCameraAsBasicFollow(std::string uEntityName, U4DVector3n uOffset){
        
        U4DEntity *entity=world->searchChild(uEntityName);
        
        if (entity!=nullptr ) {
            
            U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
            
            //Instantiate the camera
            U4DCamera *camera=U4DCamera::sharedInstance();

            //Instantiate the camera interface and the type of camera you desire
            U4DCameraInterface *cameraBasicFollow=U4DCameraBasicFollow::sharedInstance();

            //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
            cameraBasicFollow->setParameters(model,uOffset.x,uOffset.y,uOffset.z);

            //set the camera behavior
            camera->setCameraBehavior(cameraBasicFollow);
        }
        
    }

}

