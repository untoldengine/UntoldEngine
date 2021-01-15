//
//  SandboxScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "SandboxScene.h"

SandboxScene::SandboxScene(){
    
}

SandboxScene::~SandboxScene(){
    
    delete sandboxWorld;
    delete sandboxLogic;
    delete loadingScene;
}

void SandboxScene::init(){
    
    //create view component
    sandboxWorld=new SandboxWorld();
    
    //create loading screen
    loadingScene=new SandboxLoading();
    
    //create model component
    sandboxLogic=new SandboxLogic();
    
    loadComponents(sandboxWorld, loadingScene, sandboxLogic);
    
}
