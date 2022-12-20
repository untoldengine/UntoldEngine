//
//  U4DDefaultEditor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/24/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DDefaultEditor.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DSceneStateManager.h"
#include "U4DSceneEditingState.h"
#include "U4DScenePlayState.h"
#include "U4DCamera.h"
#include "U4DWorld.h"
#include "U4DModel.h"
#include "U4DResourceLoader.h"
#include "U4DEntityFactory.h"
#include "U4DRenderManager.h"

#include "U4DSerializer.h"
#include "U4DRay.h"
#include "U4DAABB.h"
#include "U4DVector3n.h"

namespace U4DEngine {

U4DDefaultEditor* U4DDefaultEditor::instance=nullptr;


U4DDefaultEditor* U4DDefaultEditor::sharedInstance(){
    
    if (instance==nullptr) {
        instance=new U4DDefaultEditor();
    }

    return instance;
}

U4DDefaultEditor::U4DDefaultEditor(){
    
}

U4DDefaultEditor::~U4DDefaultEditor(){
    
}

void U4DDefaultEditor::enter(U4DEditor *uEditor){
    U4DCamera *camera=U4DCamera::sharedInstance();
    U4DDirector *director=U4DDirector::sharedInstance();
    
    if(!(uEditor->prevCameraPosition==U4DVector3n(0.0,0.0,0.0))) camera->translateTo(uEditor->prevCameraPosition);
    if(!(uEditor->prevCameraOrientation==U4DVector3n(0.0,0.0,0.0)))
        camera->rotateTo(uEditor->prevCameraOrientation.x,uEditor->prevCameraOrientation.y,uEditor->prevCameraOrientation.z);
    
    director->setPerspectiveProjectionEnabled(true);
}

void U4DDefaultEditor::execute(U4DEditor *uEditor){
    
    uEditor->guizmoControls();
    uEditor->showProperties();
    uEditor->showOutputLog();
    uEditor->showAssets();
    uEditor->showControls();
    uEditor->showMenu();
    uEditor->cameraControls();
    uEditor->showScenegraph();
    if(uEditor->activeChild!=nullptr)
        uEditor->showEntityProperty();
    //uEditor->showGameConfigsScript();
    //uEditor->showAttributes();
    
}

void U4DDefaultEditor::exit(U4DEditor *uEditor){
    U4DCamera *camera=U4DCamera::sharedInstance();
    uEditor->prevCameraPosition=camera->getAbsolutePosition();
    uEditor->prevCameraOrientation=camera->getAbsoluteOrientation();
}

}
