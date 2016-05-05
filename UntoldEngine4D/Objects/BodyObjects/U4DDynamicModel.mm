//
//  U4DDynamicModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DDynamicModel.h"
#include "Constants.h"
#include <cmath>

namespace U4DEngine {

    U4DDynamicModel::U4DDynamicModel():affectedByPhysics(false),angularVelocity(0,0,0),velocity(0,0,0),acceleration(0,0,0),force(0,0,0),moment(0,0,0),isAwake(true),timeOfImpact(1.0),energyMotion(0.0),equilibrium(true){
    };
    

    U4DDynamicModel::~U4DDynamicModel(){};
    

    U4DDynamicModel::U4DDynamicModel(const U4DDynamicModel& value){};
    

    U4DDynamicModel& U4DDynamicModel::operator=(const U4DDynamicModel& value){return *this;};
    
    #pragma mark-add force
    void U4DDynamicModel::addForce(U4DVector3n& uForce){
        
        force+=uForce;
    }

    #pragma mark-clear forces
    void U4DDynamicModel::clearForce(){
        
        force.zero();
    }

    #pragma mark-get force
    //get force
    U4DVector3n U4DDynamicModel::getForce(){
        
        return force;
        
    }

    #pragma mark-add moment
    void U4DDynamicModel::addMoment(U4DVector3n& uMoment){
       
        moment+=uMoment;
    }

    #pragma mark-get moment
    //get moment
    U4DVector3n U4DDynamicModel::getMoment(){
        
        return moment;
    }

    #pragma mark-clear moment
    //clear moment
    void U4DDynamicModel::clearMoment(){
        
        moment.zero();
    }

    #pragma mark-get velocity
    //set and get velocity
    U4DVector3n U4DDynamicModel::getVelocity() const{
        
        return velocity;
    }

    #pragma mark-set velocity
    void U4DDynamicModel::setVelocity(U4DVector3n &uVelocity){
        
        velocity=uVelocity;
    }

    #pragma mark-get angular velocity
    U4DVector3n U4DDynamicModel::getAngularVelocity(){
        return angularVelocity;
    }

    #pragma mark-set angular velocity
    void U4DDynamicModel::setAngularVelocity(U4DVector3n& uAngularVelocity){
        
        angularVelocity=uAngularVelocity;
    }

    #pragma mark-is asleep
    //sleep
    void U4DDynamicModel::setAwake(bool uValue){
        
        isAwake=uValue;
    }

    bool U4DDynamicModel::getAwake(){
        
        return isAwake;
    }
    
    void U4DDynamicModel::determineAwakeCondition(){
        
        if (energyMotion<U4DEngine::sleepEpsilon) {
            
            //set model to sleep and zero out velocity and forces
            isAwake=false;
            velocity.zero();
            angularVelocity.zero();
            
        }else if (energyMotion>10.0*U4DEngine::sleepEpsilon){
            
            //set model awake
            energyMotion=10.0*U4DEngine::sleepEpsilon;
            isAwake=true;
        }
        
    }

    #pragma mark-motion magnitude
    //motion magnitude
    void U4DDynamicModel::determineEnergyMotion(float dt){
        
        float bias=pow(baseBias,dt);
        
        float tempEnergyMotion=velocity.dot(velocity)+angularVelocity.dot(angularVelocity);
        
        energyMotion=bias*energyMotion+(1-bias)*tempEnergyMotion;
        
    }

    float U4DDynamicModel::getEnergyMotion(){
        
        return energyMotion;
    }
    
    void U4DDynamicModel::applyPhysics(bool uValue){
        
        affectedByPhysics=uValue;
    }
    
    bool U4DDynamicModel::isPhysicsApplied(){
        
        return affectedByPhysics;
        
    }
    
    void U4DDynamicModel::setTimeOfImpact(float uTimeOfImpact){
        
        if (uTimeOfImpact>1.0) {
            
            timeOfImpact=1.0; //time of impact can't be greater than 1. Meaning no collision
            
        }else{
         
            timeOfImpact=uTimeOfImpact;
            
        }
        
    }
    
    void U4DDynamicModel::setEquilibrium(bool uValue){
        
        equilibrium=uValue;
    }
    
    bool U4DDynamicModel::getEquilibrium(){
        
        return equilibrium;
    }
    
    float U4DDynamicModel::getTimeOfImpact(){
        
        return timeOfImpact;
    }
    
    void U4DDynamicModel::resetTimeOfImpact(){
        
        timeOfImpact=1.0; //no collision
    }

}



