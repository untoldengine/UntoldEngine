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
    
    U4DRungaKuttaMethod::U4DRungaKuttaMethod(){
    
    }
    
    U4DRungaKuttaMethod::~U4DRungaKuttaMethod(){
    
    }
    
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
        
        //set the orientation
        U4DQuaternion rotation(orientationNew);
        
        //get the current translation
        U4DQuaternion t=uModel->getLocalSpacePosition();
        
        uModel->setLocalSpaceOrientation(rotation);
        
        U4DQuaternion d=(t*uModel->getLocalSpaceOrientation())*0.5;
        
        uModel->setLocalSpacePosition(d);

        //set the new angular velocity
        uModel->setAngularVelocity(angularVelocityNew);
        
    }

    void U4DRungaKuttaMethod::evaluateLinearAspect(U4DDynamicModel *uModel,U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew){
        
        U4DVector3n k1,k2,k3,k4;
        
        k1=(uLinearAcceleration)*dt;
        k2=(uLinearAcceleration+k1*0.5)*dt;
        k3=(uLinearAcceleration+k2*0.5)*dt;
        k4=(uLinearAcceleration+k3)*dt;
        
        //calculate new velocity
        uVnew=uModel->getVelocity()+(k1+k2*2+k3*2+k4)*(U4DEngine::rungaKuttaCorrectionCoefficient/6);

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
        uAngularVelocityNew=uModel->getAngularVelocity()+(k1+k2*2+k3*2+k4)*(U4DEngine::rungaKuttaCorrectionCoefficient/6);
        
        
        //get the original orientation of the body
        uOrientationNew=uModel->getLocalSpaceOrientation();
        
        //calculate the new orientation
        uOrientationNew=uOrientationNew+(uAngularVelocityNew*uOrientationNew)*(dt*0.5);
        
    }
    
}
