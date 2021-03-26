//
//  DemoScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "DemoScene.h"

DemoScene::DemoScene(){
    
}

DemoScene::~DemoScene(){
    
    delete demoWorld;
    delete demoLogic;
    delete loadingScene;
}

void DemoScene::init(){
    
    //create view component
    demoWorld=new DemoWorld();
    
    //create loading screen
    loadingScene=new DemoLoading();
    
    //create model component
    demoLogic=new DemoLogic();
    
    loadComponents(demoWorld, loadingScene, demoLogic);
    
    setAnchorMouse(true);
    
}
