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

    U4DDynamicModel::U4DDynamicModel(){
        
        affectedByPhysics=false;
        angularVelocity.zero();
        velocity.zero();
        acceleration.zero();
        force.zero();
        moment.zero();
        
        
        setAwake(true);
        
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
        
        if (uValue) {
            
            isAwake=true;
            
            //add a bit of motion to avoid it falling asleep immediately
            motion=sleepEpsilon*2;
            
        }else{
            
            isAwake=false;
            velocity.zero();
            angularVelocity.zero();
            
        }
        
        
    }

    bool U4DDynamicModel::getAwake(){
        
        return isAwake;
    }

    #pragma mark-motion magnitude
    //motion magnitude
    void U4DDynamicModel::setMotion(float uValue, float dt){
        
        float bias=pow(baseBias,dt);
        
        motion=bias*motion+(1-bias)*uValue;
        
        //prevent motion to shoot of the roof
        
        if (motion<sleepEpsilon) {
            
           // setAwake(false);
            
            
        }else if(motion>10*sleepEpsilon){
            
            motion=10*sleepEpsilon;
            
            //setAwake(true);
        }
        
    }

    float U4DDynamicModel::getMotion(){
        
        return motion;
    }
    
    void U4DDynamicModel::applyPhysics(bool uValue){
        
        affectedByPhysics=uValue;
    }
    
    bool U4DDynamicModel::isPhysicsApplied(){
        
        return affectedByPhysics;
        
    }

}



