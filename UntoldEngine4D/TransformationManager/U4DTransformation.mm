//
//  U4DTransformation.mm
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DTransformation.h"
#include <cmath>
#include "U4DQuaternion.h"
#include "U4DDualQuaternion.h"
#include "U4DVector3n.h"
#include "U4DMatrix4n.h"
#include "U4DEntity.h"
#include "CommonProtocols.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DTransformation::U4DTransformation(U4DEntity *uUObject){
        
        uEntity=uUObject;
        
    }


    void U4DTransformation::updateSpaceMatrixPosition(U4DQuaternion& translation){
        
        U4DQuaternion d=(translation*uEntity->getLocalSpaceOrientation())*0.5;
        
        uEntity->setLocalSpacePosition(d);
    }

    void U4DTransformation::updateSpaceMatrixOrientation(U4DQuaternion& orientation){
        
        //get the current translation
        U4DQuaternion t=uEntity->getLocalSpacePosition();
        
        uEntity->setLocalSpaceOrientation(orientation);
        
        U4DQuaternion d=(t*uEntity->getLocalSpaceOrientation())*0.5;
        
        uEntity->setLocalSpacePosition(d);
        
    }


    void U4DTransformation::translateTo(U4DVector3n& translation){
        
        //make non-hamilton quaternion
        U4DQuaternion t(0,translation);
        
        updateSpaceMatrixPosition(t);
        
    }

    void U4DTransformation::translateTo(float x,float y, float z){
        
        U4DVector3n vec(x,y,z);
        
        translateTo(vec);
        
    }

    void U4DTransformation::translateTo(U4DVector2n &translation){
        
        float xPos=translation.x;
        float yPos=translation.y;
        float zPos=0;
        
        U4DVector3n newTranslation(xPos,yPos,zPos);
        
        //make non-hamilton quaternion
        U4DQuaternion t(0,newTranslation);
        
        updateSpaceMatrixPosition(t);
        
    }
    
    void U4DTransformation::translateBy(float x,float y, float z){
        
        U4DVector3n pos=uEntity->getLocalPosition();
        U4DVector3n newPos(x,y,z);
        
        pos+=newPos;
        
        translateTo(pos);
    }
    
    void U4DTransformation::translateBy(U4DVector3n& translation){
        
        U4DVector3n pos=uEntity->getLocalPosition();
        
        pos+=translation;
        
        translateTo(pos);
    }

    void U4DTransformation::rotateTo(U4DQuaternion& rotation){

        rotation.convertToUnitNormQuaternion();
        
        updateSpaceMatrixOrientation(rotation);
        
    }

    void U4DTransformation::rotateTo(U4DMatrix3n& uRotationMatrix){
        
        U4DQuaternion rotation;
        
        rotation.transformMatrix3nToQuaternion(uRotationMatrix);
        
        updateSpaceMatrixOrientation(rotation);
        
    }
    
    
    void U4DTransformation::rotateTo(float angleX, float angleY, float angleZ){
        
        U4DQuaternion rotation;
        rotation.transformEulerAnglesToQuaternion(angleX, angleY, angleZ);
        
        updateSpaceMatrixOrientation(rotation);
        
    }
    
    
    void U4DTransformation::rotateTo(float angle, U4DVector3n& axis){
        
        axis.normalize();
        U4DQuaternion rotation(angle,axis);
        
        rotateTo(rotation);
        
    }

    void U4DTransformation::rotateBy(U4DQuaternion& rotation){
        
        rotation.convertToUnitNormQuaternion();
        
        U4DQuaternion currentOrientation=uEntity->getLocalSpaceOrientation();
        
        rotation=rotation*currentOrientation;
        
        //need to normalize the quaternion multiplication
        rotation.normalize();
        
        updateSpaceMatrixOrientation(rotation);
        
    }

    void U4DTransformation::rotateBy(float angleX, float angleY, float angleZ){
        
        U4DQuaternion rotation;
        rotation.transformEulerAnglesToQuaternion(angleX, angleY, angleZ);
        
        U4DQuaternion currentOrientation=uEntity->getLocalSpaceOrientation();
        
        rotation=rotation*currentOrientation;
        
        //need to normalize the quaternion multiplication
        rotation.normalize();
        
        updateSpaceMatrixOrientation(rotation);
     
    }


    void U4DTransformation::rotateBy(float angle, U4DVector3n& axis){
        
        axis.normalize();
        
        U4DQuaternion rotation(angle,axis);
        
        //need to normalize the quaternion multiplication
        rotation.normalize();
        
        rotateBy(rotation);
        
    }


    void U4DTransformation::rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition){
        
        //set a negative position vector
        U4DVector3n negPosition=axisPosition*-1;
        
        //set a zero vector to create a real quaternion
        U4DVector3n zeroVector(0,0,0);
        
        //set a pure quaternion
        U4DQuaternion pureQuaternion(0,axisPosition);
        
        //set a real quaternion
        U4DQuaternion realQuaternion(1,zeroVector);
        
        //set a dual quaternion that represents the position translation
        U4DDualQuaternion txDualQuaternion(realQuaternion,pureQuaternion);
        
        //set a negative pure quaternion
        U4DQuaternion negPureQuaternion(0,negPosition);
        
        //set a dual quaternion that represents the negative translation
        U4DDualQuaternion negTxDualQuaternion(realQuaternion,negPureQuaternion);
        
        //rotateAbout
        U4DDualQuaternion rotateAbout;
        rotateAbout=txDualQuaternion*uEntity->getLocalSpace()*negTxDualQuaternion;
        uEntity->setLocalSpace(rotateAbout);
        

        //start of rotation
        
        //normalize the axis
        axisOrientation.normalize();
        
        U4DQuaternion rotation(angle,axisOrientation);
        
        //THIS HAS TO BE HAMILTON
        rotation.convertToUnitNormQuaternion();
        
        //get the current translation
        U4DQuaternion t=uEntity->getLocalSpacePosition();
        
        uEntity->setLocalSpaceOrientation(rotation);
        
        U4DQuaternion d=(t*uEntity->getLocalSpaceOrientation())*0.5;
        
        uEntity->setLocalSpacePosition(d);
        //end of rotation
        
        
        //resetrotateAbout
        U4DDualQuaternion resetRotateAbout;
        resetRotateAbout=negTxDualQuaternion*uEntity->getLocalSpace()*txDualQuaternion;
        uEntity->setLocalSpace(resetRotateAbout);
       
    }

    void U4DTransformation::rotateAboutAxis(U4DQuaternion& uOrientation, U4DVector3n& axisPosition){
        
        //set a negative position vector
        U4DVector3n negPosition=axisPosition*-1;
        
        //set a zero vector to create a real quaternion
        U4DVector3n zeroVector(0,0,0);
        
        //set a pure quaternion
        U4DQuaternion pureQuaternion(0,axisPosition);
        
        //set a real quaternion
        U4DQuaternion realQuaternion(1,zeroVector);
        
        //set a dual quaternion that represents the position translation
        U4DDualQuaternion txDualQuaternion(realQuaternion,pureQuaternion);
        
        //set a negative pure quaternion
        U4DQuaternion negPureQuaternion(0,negPosition);
        
        //set a dual quaternion that represents the negative translation
        U4DDualQuaternion negTxDualQuaternion(realQuaternion,negPureQuaternion);
        
        //rotateAbout
        U4DDualQuaternion rotateAbout;
        rotateAbout=txDualQuaternion*uEntity->getLocalSpace()*negTxDualQuaternion;
        uEntity->setLocalSpace(rotateAbout);
        
        
        //start of rotation
        updateSpaceMatrixOrientation(uOrientation);
        //end of rotation
        
        
        //resetrotateAbout
        U4DDualQuaternion resetRotateAbout;
        resetRotateAbout=negTxDualQuaternion*uEntity->getLocalSpace()*txDualQuaternion;
        uEntity->setLocalSpace(resetRotateAbout);
        
    }

//    void U4DTransformation::viewInDirection(U4DVector3n& uDestinationPoint){
//        
//        
//        U4DVector3n upVector(0,1,0);
//        float oneEightyAngle=180.0;
//        U4DVector3n entityPosition;
//        
//        //if entity is camera, then get the local position
//        if (uEntity->getEntityType()==CAMERA) {
//            
//            entityPosition=uEntity->getLocalPosition();
//            
//        }else{
//            //else get the absolute position
//            entityPosition=uEntity->getAbsolutePosition();
//        }
//
//        //calculate the forward vector
//        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
//        
//        //calculate the angle
//        float angle=uEntity->getForwardVector().angle(forwardVector);
//       
//        //calculate the rotation axis
//        U4DVector3n rotationAxis=forwardVector.cross(uEntity->getForwardVector());
//        
//        if (uEntity->getEntityType()==CAMERA ) {
//            rotationAxis=uEntity->getForwardVector().cross(forwardVector);
//        }
//        
//        //if angle is 180 it means that both vectors are pointing opposite to each other.
//        //this means that there is no rotation axis. so set the Up Vector as the rotation axis
//        
//        if ((fabs(angle - oneEightyAngle) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(angle, zeroEpsilon)))) {
//            
//            rotationAxis=upVector;
//            angle=180.0;
//        
//        }
//        
//        rotationAxis.normalize();
//        
//        U4DQuaternion rotationQuaternion(angle,rotationAxis);
//        
//        rotationQuaternion.convertToUnitNormQuaternion();
//        
//        updateSpaceMatrixOrientation(rotationQuaternion);
//        
//        
//    }
    
}
