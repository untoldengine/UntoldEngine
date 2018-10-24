//
//  U4DCamera.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DCamera.h"
#include "U4DDirector.h"
#include "Constants.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DQuaternion.h"
#include "U4DDualQuaternion.h"
#include "U4DTransformation.h"
#include "CommonProtocols.h"
#include "U4DModel.h"
#include "U4DPlane.h"

namespace U4DEngine {
    
    U4DCamera* U4DCamera::instance=0;

    U4DCamera::U4DCamera():cameraBehavior(nullptr){
        
        entityForwardVector=U4DVector3n(0,0,1);
        
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
    
    void U4DCamera::setCameraBehavior(U4DCameraInterface *uCameraBehavior){

        cameraBehavior=uCameraBehavior;

    }
    
    void U4DCamera::update(double dt){
        
        if (cameraBehavior!=nullptr) {
            
            cameraBehavior->update(dt);
            
        }
        
    }
    
    U4DVector3n U4DCamera::getViewInDirection(){
        
        //get forward vector
        U4DVector3n forward=getEntityForwardVector();
        
        //get the entity rotation matrix
        U4DMatrix3n orientationMatrix=getLocalMatrixOrientation();
        
        //removing the invert since it is not needed due to implementation change
        //orientationMatrix.invert();
        
        return orientationMatrix*forward;
        
    }
    
    void U4DCamera::viewInDirection(U4DVector3n& uDestinationPoint){
        
        U4DVector3n upVector(0,1,0);
        U4DVector3n entityPosition;
        float oneEightyAngle=180.0;
        
        //if entity is camera, then get the local position
        entityPosition=getLocalPosition();
        
        //calculate the forward vector
        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
        
        //create a forward vector that is in the same y-plane as the entity forward vector
        U4DVector3n altPlaneForwardVector=forwardVector;
        
        altPlaneForwardVector.y=getEntityForwardVector().y;
        
        //normalize both vectors
        forwardVector.normalize();
        altPlaneForwardVector.normalize();
        
        //calculate the angle between the entity forward vector and the alternate forward vector
        float angleBetweenEntityForwardAndAltForward=getEntityForwardVector().angle(altPlaneForwardVector);
        
        //calculate the rotation axis between forward vectors
        U4DVector3n rotationAxisOfEntityAndAltForward=getEntityForwardVector().cross(altPlaneForwardVector);
        
        //if angle is 180 or -180 it means that both vectors are pointing opposite to each other.
        //this means that there is no rotation axis. so set the Up Vector as the rotation axis
        
        //Get the absolute value of the angle, so we can properly test it.
        float nAngle=fabs(angleBetweenEntityForwardAndAltForward);
        
        if ((fabs(nAngle - oneEightyAngle) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(nAngle, zeroEpsilon)))) {
            
            rotationAxisOfEntityAndAltForward=upVector;
            angleBetweenEntityForwardAndAltForward=180.0;
            
        }
        
        rotationAxisOfEntityAndAltForward.normalize();
        
        U4DQuaternion rotationAboutEntityAndAltForward(angleBetweenEntityForwardAndAltForward, rotationAxisOfEntityAndAltForward);
        
        rotateTo(rotationAboutEntityAndAltForward);
        
        //calculate the angle between the forward vector and the alternate forward vector
        float angleBetweenForwardVectorAndAltForward=forwardVector.angle(altPlaneForwardVector);
        
        //calculate the rotation axis between the forward vectors
        U4DVector3n rotationAxisOfForwardVectorAndAltForward=altPlaneForwardVector.cross(forwardVector);
        
        rotationAxisOfForwardVectorAndAltForward.normalize();
        
        U4DQuaternion rotationAboutForwardVectorAndAltForward(angleBetweenForwardVectorAndAltForward,rotationAxisOfForwardVectorAndAltForward);
        
        rotateBy(rotationAboutForwardVectorAndAltForward);
        
    }
    
    std::vector<U4DPlane> U4DCamera::getFrustumPlanes(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DEngine::U4DMatrix4n viewSpace=getLocalSpace().transformDualQuaternionToMatrix4n();
        viewSpace.invert();
        
        U4DMatrix4n perspectiveProjection=director->getPerspectiveSpace();
        
        U4DMatrix4n vpSpace=perspectiveProjection*viewSpace;
        
        // 4x4 matrix - column major. X vector is 0, 1, 2, etc.
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
        //compute left plane
        
        float m11=vpSpace.matrixData[0];
        float m12=vpSpace.matrixData[1];
        float m13=vpSpace.matrixData[2];
        float m14=vpSpace.matrixData[3];
        
        float m21=vpSpace.matrixData[4];
        float m22=vpSpace.matrixData[5];
        float m23=vpSpace.matrixData[6];
        float m24=vpSpace.matrixData[7];
        
        float m31=vpSpace.matrixData[8];
        float m32=vpSpace.matrixData[9];
        float m33=vpSpace.matrixData[10];
        float m34=vpSpace.matrixData[11];
        
        float m41=vpSpace.matrixData[12];
        float m42=vpSpace.matrixData[13];
        float m43=vpSpace.matrixData[14];
        float m44=vpSpace.matrixData[15];
        
        //compute left clipping plane
        U4DVector3n leftNormal(m14+m11,m24+m21,m34+m31);
        
        float magLeftNormal=leftNormal.magnitude();
        
        leftNormal.normalize();
        
        U4DPlane leftPlane(leftNormal,(m44+m41)/magLeftNormal);
        
        //compute right clipping plane
        
        U4DVector3n rightNormal(m14-m11,m24-m21,m34-m31);
        
        float magRightNormal=rightNormal.magnitude();
        
        rightNormal.normalize();
        
        U4DPlane rightPlane(rightNormal,(m44-m41)/magRightNormal);
        
        //compute bottom clipping plane
        
        U4DVector3n bottomNormal(m14+m12,m24+m22,m34+m32);
        
        float magBottomNormal=bottomNormal.magnitude();
        
        bottomNormal.normalize();
        
        U4DPlane bottomPlane(bottomNormal,(m44+m42)/magBottomNormal);
        
        //compute top clipping plane
        
        U4DVector3n topNormal(m14-m12,m24-m22,m34-m32);
        
        float magTopNormal=topNormal.magnitude();
        
        topNormal.normalize();
        
        U4DPlane topPlane(topNormal,(m44-m42)/magTopNormal);
        
        //compute near clipping plane
        U4DVector3n nearNormal(m13,m23,m33);
        
        float magNearNormal=nearNormal.magnitude();
        
        nearNormal.normalize();
        
        U4DPlane nearPlane(nearNormal,m43/magNearNormal);
        
        //compute far clipping plane
        U4DVector3n farNormal(m14-m13,m24-m23,m34-m33);
        
        float magFar=farNormal.magnitude();
        
        farNormal.normalize();
        
        U4DPlane farPlane(farNormal,(m44-m43)/magFar);
        
        std::vector<U4DPlane> clippingPlanes{leftPlane,rightPlane,bottomPlane,topPlane,nearPlane,farPlane};
        
        return clippingPlanes;
        
    }

}






