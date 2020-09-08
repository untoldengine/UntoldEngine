//
//  DebugScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "DebugScene.h"

DebugScene::DebugScene(){
    
}

DebugScene::~DebugScene(){
    
    delete debugWorld;
    delete debugLogic;
    
}

void DebugScene::init(){
    
    //create view component
    debugWorld=new DebugWorld(); 
    
    //create model component
    debugLogic=new DebugLogic(); 
    
    loadComponents(debugWorld, debugLogic);
    
}
