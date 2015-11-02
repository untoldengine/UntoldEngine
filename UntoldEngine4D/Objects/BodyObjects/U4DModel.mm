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
    
    U4DModel::U4DModel():hasMaterial(false),hasTextures(false),hasAnimation(false){
        
        openGlManager=new U4DOpenGL3DModel(this);
        armatureManager=new U4DArmatureData(this);
        
        openGlManager->setShader("modelShader");
        
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

    void U4DModel::receiveShadows(){
        
        setShader("shadowShader");
        
    }

}



