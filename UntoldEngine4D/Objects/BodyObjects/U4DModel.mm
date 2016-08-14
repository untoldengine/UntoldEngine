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

#import <GLKit/GLKit.h>

#pragma mark-set up the body vertices

namespace U4DEngine {
    
    U4DModel::U4DModel():hasMaterial(false),hasTextures(false),hasAnimation(false),selfShadowBias(0.005){
        
        openGlManager=new U4DOpenGL3DModel(this);
        armatureManager=new U4DArmatureData(this);
        
        openGlManager->setShader("phongShader");
        
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
    
    bool U4DModel::getHasMaterial(){
        return hasMaterial;
    }
    
    bool U4DModel::getHasTexture(){
        return hasTextures;
    }
    
    bool U4DModel::getHasAnimation(){
        return hasAnimation;
    }
    
    void U4DModel::setSelfShadowBias(float uSelfShadowBias){
        selfShadowBias=uSelfShadowBias;
    }
    
    float U4DModel::getSelfShadowBias(){
        return selfShadowBias;
    }

}



