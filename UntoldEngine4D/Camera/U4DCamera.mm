//
//  U4DCamera.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DCamera.h"
#include "Constants.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DQuaternion.h"
#include "U4DDualQuaternion.h"
#include "U4DTransformation.h"
#include "CommonProtocols.h"
#include "U4DModel.h"

namespace U4DEngine {
    
    U4DCamera* U4DCamera::instance=0;

    U4DCamera::U4DCamera(){
        
        setEntityType(CAMERA);
    }
        
    U4DCamera::~U4DCamera(){
        
    }
        
    U4DCamera* U4DCamera::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DCamera();
            
        }
        
        return instance;
    }

    void U4DCamera::setCameraPerspectiveView(float fov, float aspect, float near, float far){
        
        
        perspectiveView.computePerspectiveMatrix(fov, aspect, near, far);
        
    }

    void U4DCamera::setCameraOrthographicView(float left, float right,float bottom,float top,float near, float far){
        
        
        orthographicView.computeOrthographicMatrix(left, right, bottom, top, near, far);
        
    }

    U4DMatrix4n U4DCamera::getCameraPerspectiveView(){
        
        return perspectiveView;
    }

    U4DMatrix4n U4DCamera::getCameraOrthographicView(){
        
        return orthographicView;
    }
    
    void U4DCamera::followModel(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset){
        
        U4DVector3n modelPosition=uModel->getAbsolutePosition();
        
        //rotate to the model location
        viewInDirection(modelPosition);
        
        //translate the camera to the offset
        U4DVector3n offsetPosition(uXOffset, uYOffset, uZOffset);
        
        U4DVector3n cameraPosition=modelPosition+offsetPosition;
        
        translateTo(cameraPosition);
    
    }
    
    U4DVector3n U4DCamera::getViewInDirection(){
        
        //get forward vector
        U4DVector3n forward=getForwardVector();
        
        //get the entity rotation matrix
        U4DMatrix3n orientationMatrix=getLocalMatrixOrientation();
        
        orientationMatrix.invert();
        
        return orientationMatrix*forward;
        
    }
    
    void U4DCamera::viewInDirection(U4DVector3n& uDestinationPoint){
        
        
        U4DVector3n upVector(0,1,0);
        float oneEightyAngle=180.0;
        U4DVector3n entityPosition;
        
        //if entity is camera, then get the local position
        entityPosition=getLocalPosition();
        
        //calculate the forward vector
        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
        
        //calculate the angle
        float angle=getForwardVector().angle(forwardVector);
        
        //calculate the rotation axis
        U4DVector3n rotationAxis=getForwardVector().cross(forwardVector);
        
        //if angle is 180 it means that both vectors are pointing opposite to each other.
        //this means that there is no rotation axis. so set the Up Vector as the rotation axis
        
        if ((fabs(angle - oneEightyAngle) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(angle, zeroEpsilon)))) {
            
            rotationAxis=upVector;
            angle=180.0;
            
        }
        
        rotationAxis.normalize();
        
        U4DQuaternion rotationQuaternion(angle,rotationAxis);
        
        rotateTo(rotationQuaternion);
        
        
    }

}






