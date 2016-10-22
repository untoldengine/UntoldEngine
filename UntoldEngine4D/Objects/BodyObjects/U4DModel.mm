//
//  U4DModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DModel.h"
#include "U4DCamera.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include "U4DOpenGLManager.h"
#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "Constants.h"


#pragma mark-set up the body vertices

namespace U4DEngine {
    
    U4DModel::U4DModel():hasMaterial(false),hasTextures(false),hasAnimation(false),hasArmature(false),selfShadowBias(0.005){
        
        openGlManager=new U4DOpenGL3DModel(this);
        armatureManager=new U4DArmatureData(this);
        
        openGlManager->setShader("gouraudShader");
        
        setEntityType(MODEL);
        
    };
    
    U4DModel::~U4DModel(){
        
        delete openGlManager;
        delete armatureManager;
    };
    
    U4DModel::U4DModel(const U4DModel& value){
    
    
    };
    
    U4DModel& U4DModel::operator=(const U4DModel& value){
        
        return *this;
    
    };

    
    #pragma mark-draw
    void U4DModel::draw(){
        openGlManager->draw();
    }

    void U4DModel::drawDepthOnFrameBuffer(){
        
        openGlManager->drawDepthOnFrameBuffer();
    }

    void U4DModel::setShader(std::string uShader){
        
        openGlManager->setShader(uShader);
    }
    
    void U4DModel::setHasMaterial(bool uValue){
        
        hasMaterial=uValue;
    }
    
    void U4DModel::setHasTexture(bool uValue){
        hasTextures=uValue;
    }
    
    void U4DModel::setHasAnimation(bool uValue){
        hasAnimation=uValue;
    }
    
    void U4DModel::setHasArmature(bool uValue){
        hasArmature=uValue;
    }
    
    bool U4DModel::getHasMaterial(){
        return hasMaterial;
    }
    
    bool U4DModel::getHasTexture(){
        return hasTextures;
    }
    
    bool U4DModel::getHasAnimation(){
        return hasAnimation;
    }
    
    bool U4DModel::getHasArmature(){
        return hasArmature;
    }
    
    void U4DModel::setSelfShadowBias(float uSelfShadowBias){
        selfShadowBias=uSelfShadowBias;
    }
    
    float U4DModel::getSelfShadowBias(){
        return selfShadowBias;
    }
    
    U4DVector3n U4DModel::getViewInDirection(){
        
        //get forward vector
        U4DVector3n forward=getForwardVector();
        
        //get the entity rotation matrix
        U4DMatrix3n orientationMatrix=getLocalMatrixOrientation();
        
        return orientationMatrix*forward;
        
    }
    
    void U4DModel::viewInDirection(U4DVector3n& uDestinationPoint){
        
        U4DVector3n upVector(0,1,0);
        float oneEightyAngle=180.0;
        U4DVector3n entityPosition;
        
        entityPosition=getAbsolutePosition();
        
        //calculate the forward vector
        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
        
        //calculate the angle
        float angle=getForwardVector().angle(forwardVector);
        
        //calculate the rotation axis
        U4DVector3n rotationAxis=forwardVector.cross(getForwardVector());
        
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



