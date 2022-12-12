//
//  U4DStatesEditor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DStatesEditor.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DSceneStateManager.h"
#include "U4DScenePreviewState.h"

namespace U4DEngine {

U4DStatesEditor* U4DStatesEditor::instance=nullptr;


U4DStatesEditor* U4DStatesEditor::sharedInstance(){
    
    if (instance==nullptr) {
        instance=new U4DStatesEditor();
    }

    return instance;
}

U4DStatesEditor::U4DStatesEditor(){
    
}

U4DStatesEditor::~U4DStatesEditor(){
    
}


void U4DStatesEditor::enter(U4DEditor *uEditor){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
    sceneStateManager->changeState(U4DScenePreviewState::sharedInstance());
    uEditor->removeEverything();
    uEditor->loadPreviewPlayer();
}

void U4DStatesEditor::execute(U4DEditor *uEditor){
    
    uEditor->showOutputLog();
    uEditor->showStatesProperties();
    
    uEditor->guizmoControls();
    uEditor->showProperties();
    
    uEditor->cameraControls();
    uEditor->showEntityProperty();
    
}

void U4DStatesEditor::exit(U4DEditor *uEditor){
    
    uEditor->restoreEverything();
    
}

}
