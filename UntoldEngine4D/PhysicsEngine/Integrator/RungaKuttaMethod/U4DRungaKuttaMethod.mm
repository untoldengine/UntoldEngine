//
//  U4DRungaKuttaMethod.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DRungaKuttaMethod.h"
#include "Constants.h"
#include "U4DTransformation.h"

namespace U4DEngine {
    
#pragma mark-integrate
void U4DRungaKuttaMethod::integrate(U4DDynamicModel *uModel,float dt){
    
    U4DVector3n velocityNew(0,0,0);
    U4DVector3n displacementNew(0,0,0);
    U4DVector3n angularVelocityNew(0,0,0);
    U4DQuaternion orientationNew;
    
    //set timestep for model
    dt=dt*uModel->getTimeOfImpact();
    
    //calculate the acceleration
    U4DVector3n linearAcceleration=(uModel->getForce())*(1/uModel->getMass());
    
    //CALCULATE LINEAR POSITION
    evaluateLinearAspect(uModel,linearAcceleration, dt, velocityNew, displacementNew);
    
    //update old velocity and displacement with the new ones
    
    
    uModel->translateTo(displacementNew);
    uModel->setVelocity(velocityNew);
    
    //CALCULATE ANGULAR POSITION
    
    U4DVector3n moment=uModel->getMoment();
    
    
    U4DMatrix3n momentOfInertiaTensor=uModel->getMomentOfInertiaTensor();
    U4DMatrix3n inverseMomentOfInertia=uModel->getInverseMomentOfInertiaTensor();
    
    
    //get the angular acceleration
    U4DVector3n angularAcceleration=inverseMomentOfInertia*(moment-(uModel->getAngularVelocity().cross(momentOfInertiaTensor*uModel->getAngularVelocity())));
    
    
    //get the new angular velocity and new orientation
    evaluateAngularAspect(uModel, angularAcceleration, dt, angularVelocityNew, orientationNew);
    
    float norm=orientationNew.norm();
    
    if (norm!=0) {
        
        orientationNew.normalize();
    }
    

    //use the new orientation to rotate the object
    if(uModel->getModelHasCollided()){
        
        U4DVector3n axisOfRotation=uModel->getCollisionContactPoint();
        
        //set the new orientation and rotate
        uModel->transformation->rotateAboutAxis(orientationNew, axisOfRotation);
        
        
    }else{
    
        U4DVector3n axisOfRotation=uModel->getCenterOfMass();
        
        //set the new orientation and rotate
        uModel->transformation->rotateAboutAxis(orientationNew, axisOfRotation);
        
    }
   
    
    angularVelocityNew=angularVelocityNew-uModel->getAngularVelocity()*0.09;
    
    //set the new angular velocity
    uModel->setAngularVelocity(angularVelocityNew);

    //clear all forces and moments
    uModel->clearForce();
    uModel->clearMoment();
    
    //determine if the motion of the body is too low and set body to sleep
    float currentMotion=velocityNew.magnitudeSquare()+angularVelocityNew.magnitudeSquare();
    
    uModel->setMotion(currentMotion,dt);
    
    uModel->resetTimeOfImpact();
}

void U4DRungaKuttaMethod::evaluateLinearAspect(U4DDynamicModel *uModel,U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew){
    
    U4DVector3n k1,k2,k3,k4;
    
    k1=(uLinearAcceleration)*dt;
    k2=(uLinearAcceleration+k1*0.5)*dt;
    k3=(uLinearAcceleration+k2*0.5)*dt;
    k4=(uLinearAcceleration+k3)*dt;
    
    //calculate new velocity
    uVnew=uModel->getVelocity()+(k1+k2*2+k3*2+k4)*(rungaKuttaCorrectionCoefficient/6);

    //calculate new position
    uSnew=uModel->getLocalPosition()+uVnew*dt;
    

    
}

void U4DRungaKuttaMethod::evaluateAngularAspect(U4DDynamicModel *uModel,U4DVector3n &uAngularAcceleration,float dt,U4DVector3n &uAngularVelocityNew,U4DQuaternion &uOrientationNew){
    
    U4DVector3n k1,k2,k3,k4;
    
    //get the angular velocity
    
    k1=uAngularAcceleration*dt;
    k2=(uAngularAcceleration+k1*0.5)*dt;
    k3=(uAngularAcceleration+k2*0.5)*dt;
    k4=(uAngularAcceleration+k3)*dt;
    
    //calculate new angular velocity
    uAngularVelocityNew=uModel->getAngularVelocity()+(k1+k2*2+k3*2+k4)*(rungaKuttaCorrectionCoefficient/6);
    
    
    //get the original orientation of the body
    uOrientationNew=uModel->getLocalSpaceOrientation();
    
    //calculate the new orientation
    uOrientationNew+=(uAngularVelocityNew*uOrientationNew)*(dt*0.5);
   
}

//apply the Runga-Kutta algorithm
/*Example
 
 Consider the damped oscillating system
 x" = dv/dt = 10 - 4x - v = f(t, x, v)
 x'= dx/dt = v = g(t, x, v)
 subject to initial conditions x(0) = 1, x'(0) = 0
 Using a time step of h = 1 second
 
 We start with t = 0, x = 1, v = 0
 kf is the step for v while kg is the step for x
 kf1 = f(t, x, v) = f(0, 1, 0) = 6
 kg1 = g(t,x,v) = g(0, 1, 0) = 0
 
 kf2 = f(t+h/2, x+kg1*h/2, v+kf1*h/2)
 = f(0.5, 1, 3) = 3
 kg2 = g(t+h/2, x+kg1*h/2, v+kf1*h/2)
 = g(0.5, 1, 3) = 3
 
 kf3 = f(t+h/2, x+kg2*h/2, v+kf2*h/2)
 = f(0.5, 2.5, 1.5) = -1.5
 kg3 = g(t+h/2, x+kg2*h/2, v+kf2*h/2)
 = g(0.5, 2.5, 1.5) = 1.5
 
 kf4 = f(t+h, x+kg3*h, v+kf3*h)
 = f(1, 2.5, -1.5) = 1.5
 kg4 = g(t+h, x+kg3*h, v+kf3*h)
 = g(1, 2.5, -1.5) = -1.5
 
 At the next time value, t = 1
 x(1) = x(0) + h/6 * (kg1 + 2kg2 + 2kg3 + kg4)
 = 2.25
 x'(1) = y(0) + h/6 * (kf1 + 2kf2 + 2kf3 + kf4)
 = 1.75
 */
    
}
