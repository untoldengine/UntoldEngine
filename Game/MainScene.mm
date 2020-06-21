//
//  MainScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "MainScene.h"


MainScene::MainScene(){}

MainScene::~MainScene(){
    
    delete gameLogic;
    delete loadingWorld;
    delete earth;
    
}

void MainScene::init(){
    
    earth=new Earth();
    
    loadingWorld=new LoadingWorld();
    
    gameLogic=new GameLogic();
    
    loadComponents(earth, loadingWorld, gameLogic);
    
}

