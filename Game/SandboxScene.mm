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
    
}

void SandboxScene::init(){
    
    //create view component
    sandboxWorld=new SandboxWorld();
    
    //create model component
    sandboxLogic=new SandboxLogic();
    
    loadComponents(sandboxWorld, sandboxLogic);
    
}
