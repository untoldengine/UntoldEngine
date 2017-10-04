//
//  U4DCamera.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
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

    U4DCamera::U4DCamera(){
        
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
        U4DVector3n forward=getEntityForwardVector();
        
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
        float angle=getEntityForwardVector().angle(forwardVector);
        
        //calculate the rotation axis
        U4DVector3n rotationAxis=getEntityForwardVector().cross(forwardVector);
        
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






