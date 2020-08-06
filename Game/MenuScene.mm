//
//  MenuScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "MenuScene.h"

MenuScene::MenuScene(){
    
}

MenuScene::~MenuScene(){
    
    delete loadingWorld;
    
}

void MenuScene::init(){
    
    //create view component
    menuWorld=new MenuWorld();
    
    //create model component
    menuLogic=new MenuLogic();
    
    //create loading scene
    loadingWorld=new LoadingWorld();
    
    loadComponents(menuWorld,loadingWorld ,menuLogic);
    
}
