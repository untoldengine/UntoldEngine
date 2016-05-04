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

namespace U4DEngine {
    
U4DTransformation::U4DTransformation(U4DEntity *uUObject){
    
    uEntity=uUObject;
    
    U4DVector3n worldTransmormAxis(-0.707107,0,0);
    
    U4DQuaternion world(0.707107,worldTransmormAxis);
    
    worldTransform=world;
    
}


void U4DTransformation::updateSpaceMatrixPosition(U4DQuaternion& translation){
    
    U4DQuaternion d=(translation*uEntity->getLocalSpaceOrientation())*0.5;
    
    uEntity->setLocalSpacePosition(d);
}

void U4DTransformation::updateSpaceMatrixOrientation(U4DQuaternion& orientation){
    
    //get the current translation
    U4DQuaternion t=uEntity->getLocalSpaceTranslation();
    
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

void U4DTransformation::rotateTo(U4DQuaternion& rotation){
    

    rotation.convertToUnitNormQuaternion();
    
    //update view direction
    uEntity->updateViewDirection(rotation);
    
    if (uEntity->getEntityType()==MODEL) {
    
    rotation=rotation*worldTransform;
        
    }
    
    updateSpaceMatrixOrientation(rotation);
    
}

void U4DTransformation::rotateTo(U4DMatrix3n& uRotationMatrix){
    
    U4DQuaternion rotation;
    
    rotation.transformMatrix3nToQuaternion(uRotationMatrix);
    
    //update view direction
    uEntity->updateViewDirection(rotation);
    
    if (uEntity->getEntityType()==MODEL) {
        
        rotation=rotation*worldTransform;
    }
    
    updateSpaceMatrixOrientation(rotation);
    
}

void U4DTransformation::rotateBy(U4DQuaternion& rotation){
    
    rotation.convertToUnitNormQuaternion();
    
    //update view direction
    uEntity->updateViewDirection(rotation);
    
    U4DQuaternion currentOrientation=uEntity->getLocalSpaceOrientation();
    
    rotation=rotation*currentOrientation;
    
    updateSpaceMatrixOrientation(rotation);
    
}


void U4DTransformation::rotateTo(float angleX, float angleY, float angleZ){
    
    U4DQuaternion rotation;
    rotation.transformEulerAnglesToQuaternion(angleX, angleY, angleZ);
    
    //update view direction
    uEntity->updateViewDirection(rotation);
    
    if (uEntity->getEntityType()==MODEL) {
    
        rotation=rotation*worldTransform;
        
    }
    
    updateSpaceMatrixOrientation(rotation);
    
}

void U4DTransformation::rotateBy(float angleX, float angleY, float angleZ){
    
    U4DQuaternion rotation;
    rotation.transformEulerAnglesToQuaternion(angleX, angleY, angleZ);
    
    U4DQuaternion currentOrientation=uEntity->getLocalSpaceOrientation();
    
    //update view direction
    uEntity->updateViewDirection(rotation);
    
    rotation=rotation*currentOrientation;
    
    updateSpaceMatrixOrientation(rotation);
 
}


void U4DTransformation::rotateTo(float angle, U4DVector3n& axis){
    
    axis.normalize();
    U4DQuaternion rotation(angle,axis);
    
    rotateTo(rotation);
    
}

void U4DTransformation::rotateBy(float angle, U4DVector3n& axis){
    
    axis.normalize();
    U4DQuaternion rotation(angle,axis);
    
    
    rotateBy(rotation);
    
}


void U4DTransformation::translateBy(float x,float y, float z){
    
    U4DVector3n pos=uEntity->getLocalPosition();
    U4DVector3n newPos(x,y,z);
    
    pos+=newPos;
    
    translateTo(pos);
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
    
    
    if (uEntity->getEntityType()==MODEL) {
        
        rotation=rotation*worldTransform;
        
    }
    
    //get the current translation
    U4DQuaternion t=uEntity->getLocalSpaceTranslation();
    
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

void U4DTransformation::viewInDirection(U4DVector3n& uDestinationPoint){
    
    /*
     zaxis = normal(cameraTarget - cameraPosition)
     xaxis = normal(cross(cameraUpVector, zaxis))
     yaxis = cross(zaxis, xaxis)
     
     xaxis.x           yaxis.x           zaxis.x          0
     xaxis.y           yaxis.y           zaxis.y          0
     xaxis.z           yaxis.z           zaxis.z          0
     -dot(xaxis, cameraPosition)  -dot(yaxis, cameraPosition)  -dot(zaxis, cameraPosition)  1
     
     
     The three input vectors represent the following, respectively:
     The eye point: [0, 3, -5].
     The camera look-at target: the origin [0, 0, 0].
     The current world's up-direction: usually [0, 1, 0].
     
     LookAtLH(
     new Vector3(0.0f, 3.0f, -5.0f),
     new Vector3(0.0f, 0.0f, 0.0f),
     new Vector3(0.0f, 1.0f, 0.0f));
     
     
     LookAtLH(
     Vector3 cameraPosition,
     Vector3 cameraTarget,
     Vector3 cameraUpVector
     );
     
     */
    
    U4DVector3n up(0,1,0);
    
    U4DVector3n parentPosition(0,0,0);
    
    if (uEntity->parent!=NULL) {
        parentPosition=uEntity->parent->getLocalPosition();
    }
    
    U4DVector3n zAxis=uEntity->getAbsolutePosition()-uDestinationPoint;
    
    zAxis.normalize();
    
    U4DVector3n xAxis=up.cross(zAxis);
    xAxis.normalize();
    
    U4DVector3n yAxis=zAxis.cross(xAxis);
    yAxis.normalize();
    
    
    U4DMatrix3n m(xAxis.x,yAxis.x,zAxis.x,
                  xAxis.y,yAxis.y,zAxis.y,
                  xAxis.z,yAxis.z,zAxis.z);
    
    
    rotateTo(m);
    
}
    
}
