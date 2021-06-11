//
//  U4DDynamicAction.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DDynamicAction.h"
#include "Constants.h"
#include <cmath>
#include "U4DDirector.h"
#include "U4DKineticDictionary.h"
#include "U4DEntityManager.h"

namespace U4DEngine {

    U4DDynamicAction::U4DDynamicAction(U4DModel *uU4DModel):U4DStaticAction(uU4DModel),kineticsEnabled(false),angularVelocity(0,0,0),velocity(0,0,0),acceleration(0,0,0),force(0,0,0),moment(0,0,0),isAwake(false),timeOfImpact(1.0),modelKineticEnergy(0.0),equilibrium(false),gravity(0.0,-10.0,0.0),dragCoefficient(0.9,0.9){
        
        //load into dictionary
        U4DKineticDictionary *kineticDictionary=U4DKineticDictionary::sharedInstance();
        
        kineticDictionary->loadBehaviorDictionary(name, this);
        
    };
    

    U4DDynamicAction::~U4DDynamicAction(){
        
        U4DKineticDictionary *kineticDictionary=U4DKineticDictionary::sharedInstance();
        
        kineticDictionary->removeKineticBehavior(name);
        
    };
    

    U4DDynamicAction::U4DDynamicAction(const U4DDynamicAction& value):U4DStaticAction(value){};
    

    U4DDynamicAction& U4DDynamicAction::operator=(const U4DDynamicAction& value){return *this;};
    
    #pragma mark-add force
    void U4DDynamicAction::addForce(U4DVector3n& uForce){
        
        force+=uForce;
    }

    #pragma mark-clear forces
    void U4DDynamicAction::clearForce(){
        
        force.zero();
    }

    #pragma mark-get force
    //get force
    U4DVector3n U4DDynamicAction::getForce(){
        
        return force;
        
    }

    #pragma mark-add moment
    void U4DDynamicAction::addMoment(U4DVector3n& uMoment){
       
        moment+=uMoment;
    }

    #pragma mark-get moment
    //get moment
    U4DVector3n U4DDynamicAction::getMoment(){
        
        return moment;
    }

    #pragma mark-clear moment
    //clear moment
    void U4DDynamicAction::clearMoment(){
        
        moment.zero();
    }

    #pragma mark-get velocity
    //set and get velocity
    U4DVector3n U4DDynamicAction::getVelocity(){
        
        return velocity;
    }

    #pragma mark-set velocity
    void U4DDynamicAction::setVelocity(U4DVector3n &uVelocity){
        
        velocity=uVelocity;
    }

    #pragma mark-get angular velocity
    U4DVector3n U4DDynamicAction::getAngularVelocity(){
        return angularVelocity;
    }

    #pragma mark-set angular velocity
    void U4DDynamicAction::setAngularVelocity(U4DVector3n& uAngularVelocity){
        
        angularVelocity=uAngularVelocity;
    }

    #pragma mark-is asleep
    //sleep
    void U4DDynamicAction::setAwake(bool uValue){
        
        if (uValue) {

            isAwake=true;
            
            //Add a bit of motion to avoid model from falling asleep immediately.
            modelKineticEnergy=U4DEngine::sleepEpsilon*2.0f;
            
        }else{
            //set model to sleep and zero out velocity and forces
            isAwake=false;
            modelKineticEnergy=0.0;
            velocity.zero();
            angularVelocity.zero();
            clearForce();
            clearMoment();
        }
    }

    bool U4DDynamicAction::getAwake(){
        
        return isAwake;
        
    }
    

    #pragma mark-energy motion
    //energy motion
    void U4DDynamicAction::computeModelKineticEnergy(float dt){
        
        float currentEnergyMotion=velocity.dot(velocity)+angularVelocity.dot(angularVelocity);
        
        float bias=pow(U4DEngine::sleepBias,dt);
        
        modelKineticEnergy=bias*modelKineticEnergy+(1-bias)*currentEnergyMotion;
        
        if (modelKineticEnergy<U4DEngine::sleepEpsilon && equilibrium==true) {
            
            setAwake(false);
            
        }
        
    }

    float U4DDynamicAction::getModelKineticEnergy(){
        
        return modelKineticEnergy;
    }
    
    void U4DDynamicAction::enableKineticsBehavior(){
        
        //make sure that the inertia tensor has been computed before applying physics
        computeInertiaTensor();
        
        kineticsEnabled=true;
        
        //wake up the model
        setAwake(true);
        
    }
    
    void U4DDynamicAction::pauseKineticsBehavior(){
        
        kineticsEnabled=false;
        
        setAwake(false);
    }
    
    void U4DDynamicAction::resumeKineticsBehavior(){
        
        kineticsEnabled=true;
        
        setAwake(true);
    }
    
    bool U4DDynamicAction::isKineticsBehaviorEnabled(){
        
        return kineticsEnabled;
        
    }
    
    void U4DDynamicAction::setTimeOfImpact(float uTimeOfImpact){
        
        if (uTimeOfImpact>1.0) {
            
            timeOfImpact=1.0; //time of impact can't be greater than 1. Meaning no collision
            
        }else{
         
            timeOfImpact=uTimeOfImpact;
            
        }
        
    }
    
    void U4DDynamicAction::setEquilibrium(bool uValue){
        
        equilibrium=uValue;
    }
    
    bool U4DDynamicAction::getEquilibrium(){
        
        return equilibrium;
    }
    
    float U4DDynamicAction::getTimeOfImpact(){
        
        return timeOfImpact;
    }
    
    void U4DDynamicAction::resetTimeOfImpact(){
        
        timeOfImpact=1.0; //no collision
    }
    
    void U4DDynamicAction::setGravity(U4DVector3n& uGravity){
    
        gravity=uGravity;
    }
    
    U4DVector3n U4DDynamicAction::getGravity(){
        return gravity;
    }
    
    void U4DDynamicAction::resetGravity(){
        
        gravity=U4DVector3n(0.0,-10.0,0.0);
        
    }
    
    void U4DDynamicAction::setDragCoefficient(U4DVector2n& uDragCoefficient){
        
        dragCoefficient=uDragCoefficient;
    }
    
    U4DVector2n U4DDynamicAction::getDragCoefficient(){
        
        return dragCoefficient;
    }
    
    void U4DDynamicAction::resetDragCoefficient(){
        
        dragCoefficient=U4DVector2n(0.9,0.9);
    }
    
    void U4DDynamicAction::loadIntoCollisionEngine(U4DEntityManager *uEntityManager){
        
        uEntityManager->loadIntoCollisionEngine(this);
        
    }
    
    void U4DDynamicAction::loadIntoPhysicsEngine(U4DEntityManager *uEntityManager, float dt){
        
        uEntityManager->loadIntoPhysicsEngine(this, dt);
        
    }
    
    
    
    void U4DDynamicAction::cleanUp(){
        
        //clear any collision information
        clearCollisionInformation();
        
        //reset time of impact
        resetTimeOfImpact();
        
        //reset equilibrium
        setEquilibrium(false);
        
        //set as non-collided
        setModelHasCollided(false);
        setModelHasCollidedBroadPhase(false);
        
        //clear collision list
        clearCollisionList();
        clearBroadPhaseCollisionList();
        
    }
}



