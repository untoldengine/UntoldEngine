//
//  StartScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "StartScene.h"

StartScene::StartScene(){
    
}

StartScene::~StartScene(){
    
    delete startMenu;
    delete startLogic;
    
}

void StartScene::init(){
    
    //create view component
    startMenu=new StartMenu();
    
    //create model component
    startLogic=new StartLogic();
    
    loadComponents(startMenu,startLogic);
    
}
