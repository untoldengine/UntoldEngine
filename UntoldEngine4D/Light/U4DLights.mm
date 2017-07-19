//
//  U4DLight.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DLights.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DRenderLights.h"

namespace U4DEngine {
    
    U4DLights* U4DLights::instance=0;
    
    U4DLights::U4DLights(){
        
        renderManager=new U4DRenderLights(this);
        
        U4DPoint3n uMax(0.1,0.1,0.1);
        U4DPoint3n uMin(-0.1,-0.1,-0.1);
        
        computeLightVolume(uMax, uMin);
        
        setEntityType(LIGHT);
        
        translateTo(0.0,0.0,0.0);
        
        setShader("vertexLightShader", "fragmentLightShader");
        
        renderManager->loadRenderingInformation();
       
    };
    
    U4DLights::~U4DLights(){
        
    };
    
    U4DLights* U4DLights::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DLights();
        }
        
        return instance;
    }
    
    void U4DLights::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
    }
    
    void U4DLights::computeLightVolume(U4DPoint3n& uMin,U4DPoint3n& uMax){
        
        float width=(std::abs(uMax.x-uMin.x))/2.0;
        float height=(std::abs(uMax.y-uMin.y))/2.0;
        float depth=(std::abs(uMax.z-uMin.z))/2.0;
        
        U4DVector3n v1(width,height,depth);
        U4DVector3n v2(width,height,-depth);
        U4DVector3n v3(-width,height,-depth);
        U4DVector3n v4(-width,height,depth);
        
        U4DVector3n v5(width,-height,depth);
        U4DVector3n v6(width,-height,-depth);
        U4DVector3n v7(-width,-height,-depth);
        U4DVector3n v8(-width,-height,depth);
        
        U4DIndex i1(0,1,2);
        U4DIndex i2(2,3,0);
        U4DIndex i3(4,5,6);
        U4DIndex i4(6,7,4);
        
        U4DIndex i5(5,6,2);
        U4DIndex i6(2,3,7);
        U4DIndex i7(7,4,5);
        U4DIndex i8(5,1,0);
        
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        bodyCoordinates.addVerticesDataToContainer(v4);
        
        bodyCoordinates.addVerticesDataToContainer(v5);
        bodyCoordinates.addVerticesDataToContainer(v6);
        bodyCoordinates.addVerticesDataToContainer(v7);
        bodyCoordinates.addVerticesDataToContainer(v8);
        
        bodyCoordinates.addIndexDataToContainer(i1);
        bodyCoordinates.addIndexDataToContainer(i2);
        bodyCoordinates.addIndexDataToContainer(i3);
        bodyCoordinates.addIndexDataToContainer(i4);
        
        bodyCoordinates.addIndexDataToContainer(i5);
        bodyCoordinates.addIndexDataToContainer(i6);
        bodyCoordinates.addIndexDataToContainer(i7);
        bodyCoordinates.addIndexDataToContainer(i8);
        
        
    }
    
    U4DVector3n U4DLights::getViewInDirection(){
        
        //get forward vector
        U4DVector3n forward=getEntityForwardVector();
        
        //get the entity rotation matrix
        U4DMatrix3n orientationMatrix=getLocalMatrixOrientation();
        
        return orientationMatrix*forward;
        
    }
    
    void U4DLights::viewInDirection(U4DVector3n& uDestinationPoint){
        
        U4DVector3n upVector(0,1,0);
        float oneEightyAngle=180.0;
        U4DVector3n entityPosition;
        
        entityPosition=getAbsolutePosition();
        
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

}
