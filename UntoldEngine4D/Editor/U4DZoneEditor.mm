//
//  U4DZoneEditor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/25/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DZoneEditor.h"
#include "U4DDirector.h"
#include "U4DCamera.h"

namespace U4DEngine {

U4DZoneEditor* U4DZoneEditor::instance=nullptr;


U4DZoneEditor* U4DZoneEditor::sharedInstance(){
    
    if (instance==nullptr) {
        instance=new U4DZoneEditor();
    }

    return instance;
}

U4DZoneEditor::U4DZoneEditor(){
    
}

U4DZoneEditor::~U4DZoneEditor(){
    
}


void U4DZoneEditor::enter(U4DEditor *uEditor){
    
    U4DDirector *director=U4DDirector::sharedInstance();
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    U4DVector3n upVector(1.0,0.0,0.0);
    U4DVector3n pos(0.0,camera->getLargestDistanceFromSceneOrigin(),0.0);
    camera->rotateTo(90.0,upVector);
    camera->translateTo(pos);
    
    director->setPerspectiveProjectionEnabled(false);
}

void U4DZoneEditor::execute(U4DEditor *uEditor){
    
    U4DDirector *director=U4DDirector::sharedInstance();
    float mouseWheelH=ImGui::GetIO().MouseWheelH;
    float mouseWheelV=ImGui::GetIO().MouseWheel;
    
    if(ImGui::GetIO().KeyCtrl==true && mouseWheelH==0.0){
        
        if (director->getPerspectiveProjectionEnabled()==false) {
            float orthographicScale=director->getOrthographicScale();
            
            orthographicScale+=mouseWheelV;
            
            director->setOrthographicScale(orthographicScale);
            
        }
        
    }
    
    uEditor->divideZones();
    
    uEditor->showOutputLog();
}

void U4DZoneEditor::exit(U4DEditor *uEditor){
    
}

}
