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

    void U4DCamera::setCameraProjectionView(float fov, float aspect, float near, float far){
        
        
        projectionView.computePerspectiveMatrix(fov, aspect, near, far);
        
    }

    void U4DCamera::setCameraOrthographicView(float left, float right,float bottom,float top,float near, float far){
        
        
        orthographicView.computeOrthographicMatrix(left, right, bottom, top, near, far);
        
    }

    U4DMatrix4n U4DCamera::getCameraProjectionView(){
        
        return projectionView;
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

}






