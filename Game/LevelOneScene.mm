//
//  LevelOneScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "LevelOneScene.h"


LevelOneScene::LevelOneScene(){}

LevelOneScene::~LevelOneScene(){
    
    delete levelOneLogic;
    delete loadingWorld;
    delete levelOneWorld;
    
}

void LevelOneScene::init(){
    
    levelOneWorld=new LevelOneWorld();
    
    loadingWorld=new LoadingWorld();
    
    levelOneLogic=new LevelOneLogic();
    
    loadComponents(levelOneWorld, loadingWorld, levelOneLogic);
    
    //anchor mouse
    setAnchorMouse(true);
    
}

