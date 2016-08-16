//
//  U4DCollisionResponse.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DCollisionResponse.h"
#include "Constants.h"
#include "U4DDynamicModel.h"


namespace U4DEngine {
    
    U4DCollisionResponse::U4DCollisionResponse(){
    
    }
    
    U4DCollisionResponse::~U4DCollisionResponse(){
    
    }
    
    void U4DCollisionResponse::collisionResolution(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,COLLISIONMANIFOLDONODE &uCollisionManifoldNode){
        
        //set the linear and angular factor for each model
        U4DVector3n linearImpulseFactorOfModel1(0,0,0);
        U4DVector3n angularImpulseFactorOfModel1(0,0,0);
        
        U4DVector3n linearImpulseFactorOfModel2(0,0,0);
        U4DVector3n angularImpulseFactorOfModel2(0,0,0);
        
        //Clear all forces
        uModel1->clearForce();
        uModel1->clearMoment();
        
        uModel2->clearForce();
        uModel2->clearMoment();
        
        //get the contact point and line of action
        
        std::vector<U4DVector3n> contactManifold=uCollisionManifoldNode.contactPoints;
        
        if (contactManifold.size()>4) {
            contactManifold.resize(4);
        }
        
        U4DVector3n normalCollisionVector=uCollisionManifoldNode.normalCollisionVector;
        
        U4DVector3n centerOfMassForModel1=uModel1->getCenterOfMass()+uModel1->getAbsolutePosition();
        U4DVector3n centerOfMassForModel2=uModel2->getCenterOfMass()+uModel2->getAbsolutePosition();
        
        float inverseMassOfModel1=1.0/uModel1->getMass();
        float inverseMassOfModel2=1.0/uModel2->getMass();
        float totalInverseMasses=inverseMassOfModel1+inverseMassOfModel2;
    
        for(auto n:contactManifold){
            
            U4DVector3n radiusOfModel1=n-centerOfMassForModel1;
            U4DVector3n radiusOfModel2=n-centerOfMassForModel2;
            
            //get the velocity model
            /*
             r=contact point
             vp=v+(wxr)
             */
            
            U4DVector3n vpModel1=uModel1->getVelocity()+(uModel1->getAngularVelocity().cross(radiusOfModel1));
            U4DVector3n vpModel2=uModel2->getVelocity()+(uModel2->getAngularVelocity().cross(radiusOfModel2));
            
            U4DVector3n vR=vpModel2-vpModel1;
            
            /*
             
             See page 115 in Physics for game developers
             
             |J|=-(Vr*n)(e+1)/[1/m +n*((rxn)/I)xr]
             
             */
            
            U4DVector3n angularFactorOfModel1=uModel1->getInverseMomentOfInertiaTensor()*(radiusOfModel1.cross(normalCollisionVector)).cross(radiusOfModel1);
            
            U4DVector3n angularFactorOfModel2=uModel2->getInverseMomentOfInertiaTensor()*(radiusOfModel2.cross(normalCollisionVector)).cross(radiusOfModel2);
            
            float totalAngularEffect=normalCollisionVector.dot(angularFactorOfModel1+angularFactorOfModel2);
            
            //Compute coefficient of restitution for both bodies
            float coefficientOfRestitution=uModel1->getCoefficientOfRestitution()*uModel2->getCoefficientOfRestitution();
            
            float j=MAX(-1*(vR.dot(normalCollisionVector))*(coefficientOfRestitution+1.0)/(totalInverseMasses+totalAngularEffect),U4DEngine::impulseCollisionMinimum);
            
            
            /*
             
             Linear Impulse factor=(|J|n)/m
             
             */
            
            linearImpulseFactorOfModel1+=(normalCollisionVector*j)*inverseMassOfModel1;
            linearImpulseFactorOfModel2+=(normalCollisionVector*j)*inverseMassOfModel2;
            
            /*
             
             Angular Impulse factor=(rx|j|n)/I
             */
            
            
            angularImpulseFactorOfModel1+=uModel1->getInverseMomentOfInertiaTensor()*(radiusOfModel1.cross(normalCollisionVector*j));
            
            angularImpulseFactorOfModel2+=uModel2->getInverseMomentOfInertiaTensor()*(radiusOfModel2.cross(normalCollisionVector*j));
    
        }
        //Add the new velocity to the previous velocity
        /*
         
         V1after=V1before+(|J|n)/m
         
         */
        
        U4DVector3n newLinearVelocityOfModel1=uModel1->getVelocity()-linearImpulseFactorOfModel1;
        U4DVector3n newLinearVelocityOfModel2=uModel2->getVelocity()+linearImpulseFactorOfModel2;
        
        //Add the new angular velocity to the previous velocity
        /*
         
         w1after=w1before+(rx|j|n)/I
         */
        
        //determine if model are in equilibrium. If it is, then the angular velocity should be ommitted since there should be no rotation. This prevents from angular velocity to creep into the linear velocity
        
        if (uModel1->getEquilibrium()) {
            
            angularImpulseFactorOfModel1.zero();
            
        }
        
        if (uModel2->getEquilibrium()) {
        
            angularImpulseFactorOfModel2.zero();
            
        }
        
        U4DVector3n newAngularVelocityOfModel1=uModel1->getAngularVelocity()-angularImpulseFactorOfModel1;
        U4DVector3n newAngularVelocityOfModel2=uModel2->getAngularVelocity()+angularImpulseFactorOfModel2;
        
        //Set the new linear and angular velocities for the models
        
        if (uModel1->isKineticsBehaviorEnabled()) {
            
            uModel1->setVelocity(newLinearVelocityOfModel1);
            
            uModel1->setAngularVelocity(newAngularVelocityOfModel1);
            
        }
        
        
        if(uModel2->isKineticsBehaviorEnabled()){
            
            uModel2->setVelocity(newLinearVelocityOfModel2);
            
            uModel2->setAngularVelocity(newAngularVelocityOfModel2);
        }
        
    }
    
}