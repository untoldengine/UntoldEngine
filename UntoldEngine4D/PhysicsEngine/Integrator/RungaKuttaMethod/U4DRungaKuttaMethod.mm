//
//  U4DRungaKuttaMethod.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DRungaKuttaMethod.h"
#include "Constants.h"
#include "U4DModel.h"
#include "U4DTransformation.h"

namespace U4DEngine {
    
    U4DRungaKuttaMethod::U4DRungaKuttaMethod(){
    
    }
    
    U4DRungaKuttaMethod::~U4DRungaKuttaMethod(){
    
    }
    
    #pragma mark-integrate
    void U4DRungaKuttaMethod::integrate(U4DDynamicAction *uAction,float dt){
        
        U4DVector3n velocityNew(0,0,0);
        U4DVector3n displacementNew(0,0,0);
        U4DVector3n angularVelocityNew(0,0,0);
        U4DQuaternion orientationNew;
        
        //set timestep for model
        dt=dt*uAction->getTimeOfImpact();
        
        //calculate the acceleration
        U4DVector3n linearAcceleration=(uAction->getForce())*(1/uAction->getMass());
        
        //CALCULATE LINEAR POSITION
        evaluateLinearAspect(uAction,linearAcceleration, dt, velocityNew, displacementNew);
        
        //update old velocity and displacement with the new ones
        
        
        uAction->model->translateTo(displacementNew);
        uAction->setVelocity(velocityNew);


        //CALCULATE ANGULAR POSITION
        
        U4DVector3n moment=uAction->getMoment();
        
        U4DMatrix3n momentOfInertiaTensor=uAction->getMomentOfInertiaTensor();
        U4DMatrix3n inverseMomentOfInertia=uAction->getInverseMomentOfInertiaTensor();
        
        //get the angular acceleration
        U4DVector3n angularAcceleration=inverseMomentOfInertia*(moment-(uAction->getAngularVelocity().cross(momentOfInertiaTensor*uAction->getAngularVelocity())));
        
        
        
        //get the new angular velocity and new orientation
        evaluateAngularAspect(uAction, angularAcceleration, dt, angularVelocityNew, orientationNew);

        
        float norm=orientationNew.norm();
        
        if (norm!=0) {
            
            orientationNew.normalize();
        }
        
        //set the orientation
        U4DQuaternion rotation(orientationNew);
        
        //get the current translation
        U4DQuaternion t=uAction->model->getLocalSpacePosition();
        
        uAction->model->setLocalSpaceOrientation(rotation);
        
        U4DQuaternion d=(t*uAction->model->getLocalSpaceOrientation())*0.5;
        
        uAction->model->setLocalSpacePosition(d);

        //set the new angular velocity
        uAction->setAngularVelocity(angularVelocityNew);
        
    }

    void U4DRungaKuttaMethod::evaluateLinearAspect(U4DDynamicAction *uAction,U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew){
        
        U4DVector3n k1,k2,k3,k4;
        
        k1=(uLinearAcceleration)*dt;
        k2=(uLinearAcceleration+k1*0.5)*dt;
        k3=(uLinearAcceleration+k2*0.5)*dt;
        k4=(uLinearAcceleration+k3)*dt;
        
        //calculate new velocity
        uVnew=uAction->getVelocity()+(k1+k2*2+k3*2+k4)*(U4DEngine::rungaKuttaCorrectionCoefficient/6);

        //calculate new position
        uSnew=uAction->model->getLocalPosition()+uVnew*dt;
        
    }

    void U4DRungaKuttaMethod::evaluateAngularAspect(U4DDynamicAction *uAction,U4DVector3n &uAngularAcceleration,float dt,U4DVector3n &uAngularVelocityNew,U4DQuaternion &uOrientationNew){
        
        U4DVector3n k1,k2,k3,k4;
        
        //get the angular velocity
        
        k1=uAngularAcceleration*dt;
        k2=(uAngularAcceleration+k1*0.5)*dt;
        k3=(uAngularAcceleration+k2*0.5)*dt;
        k4=(uAngularAcceleration+k3)*dt;

        
        //calculate new angular velocity
        uAngularVelocityNew=uAction->getAngularVelocity()+(k1+k2*2+k3*2+k4)*(U4DEngine::rungaKuttaCorrectionCoefficient/6);
        
        
        //get the original orientation of the body
        uOrientationNew=uAction->model->getLocalSpaceOrientation();
        
        //calculate the new orientation
        uOrientationNew=uOrientationNew+(uAngularVelocityNew*uOrientationNew)*(dt*0.5);
        
    }
    
}
