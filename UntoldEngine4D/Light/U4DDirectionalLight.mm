//
//  U4DLight.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#include "U4DDirectionalLight.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    U4DDirectionalLight* U4DDirectionalLight::instance=0;
    
    U4DDirectionalLight::U4DDirectionalLight():diffuseColor(1.0,1.0,1.0), specularColor(1.0,1.0,1.0){
               
    };
    
    U4DDirectionalLight::~U4DDirectionalLight(){
        
    };
    
    U4DDirectionalLight* U4DDirectionalLight::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DDirectionalLight();
        }
        
        return instance;
    }
    
    U4DVector3n U4DDirectionalLight::getViewInDirection(){
        
        //get forward vector
        U4DVector3n forward=getEntityForwardVector();
        
        //get the entity rotation matrix
        U4DMatrix3n orientationMatrix=getLocalMatrixOrientation();
        
        return orientationMatrix*forward;
        
    }
    
    void U4DDirectionalLight::viewInDirection(U4DVector3n& uDestinationPoint){
        
        U4DVector3n upVector(0,1,0);
        U4DVector3n entityPosition;
        float oneEightyAngle=180.0;
        
        //Get the absolute position
        entityPosition=getAbsolutePosition();
        
        //calculate the forward vector
        U4DVector3n forwardVector=entityPosition-uDestinationPoint;
        
        //create a forward vector that is in the same y-plane as the entity forward vector
        U4DVector3n altPlaneForwardVector=forwardVector;
        
        //normalize both vectors
        forwardVector.normalize();
        altPlaneForwardVector.normalize();
        
        //calculate the angle between the entity forward vector and the alternate forward vector
        float angleBetweenEntityForwardAndAltForward=getEntityForwardVector().angle(altPlaneForwardVector);
        
        //calculate the rotation axis between forward vectors
        U4DVector3n rotationAxisOfEntityAndAltForward=altPlaneForwardVector.cross(getEntityForwardVector());
        
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
        U4DVector3n rotationAxisOfForwardVectorAndAltForward=forwardVector.cross(altPlaneForwardVector);
        
        rotationAxisOfForwardVectorAndAltForward.normalize();
        
        U4DQuaternion rotationAboutForwardVectorAndAltForward(angleBetweenForwardVectorAndAltForward,rotationAxisOfForwardVectorAndAltForward);
        
        rotateBy(rotationAboutForwardVectorAndAltForward);
        
        
        //Code used for original view direction of light. Leaving it here just in case.
        
//        U4DVector3n upVector(0,1,0);
//        float oneEightyAngle=180.0;
//        U4DVector3n entityPosition;
//
//        entityPosition=getAbsolutePosition();
//
//        //calculate the forward vector
//        U4DVector3n forwardVector=entityPosition-uDestinationPoint;
//
//        //calculate the angle
//        float angle=getEntityForwardVector().angle(forwardVector);
//
//        //calculate the rotation axis
//        U4DVector3n rotationAxis=forwardVector.cross(getEntityForwardVector());
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
//        rotateTo(rotationQuaternion);
        
    }
    
    void U4DDirectionalLight::setDiffuseColor(U4DVector3n &uDiffuseColor){
        
        if ((uDiffuseColor.x>=0.0 && uDiffuseColor.x<=1.0) && (uDiffuseColor.y>=0.0 && uDiffuseColor.y<=1.0) && (uDiffuseColor.z>=0.0 && uDiffuseColor.z<=1.0)) {
            
            diffuseColor=uDiffuseColor;
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("Error: The value for the Diffuse Light Color parameter should be between 0 and 1");
        }
        
        
    }
    
    void U4DDirectionalLight::setSpecularColor(U4DVector3n &uSpecularColor){
        
        if ((uSpecularColor.x>=0.0 && uSpecularColor.x<=1.0) && (uSpecularColor.y>=0.0 && uSpecularColor.y<=1.0) && (uSpecularColor.z>=0.0 && uSpecularColor.z<=1.0)) {
            
            specularColor=uSpecularColor;
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("Error: The value for the Specular Light Color parameter should be between 0 and 1");
        }
        
        
    }
    
    U4DVector3n U4DDirectionalLight::getDiffuseColor(){
        
        return diffuseColor;
        
    }
    
    U4DVector3n U4DDirectionalLight::getSpecularColor(){
        
        return specularColor;
        
    }

}
