//
//  MainScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "MainScene.h"
#include "Earth.h"
#include "GameController.h"
#include "GamePadControllers.h"
#include "GameLogic.h"
#include "U4DGameModelInterface.h"
#include "U4DTouchesController.h"
#include "U4DGamepadController.h"

MainScene::MainScene(){}

MainScene::~MainScene(){}

void MainScene::init(){
    
    Earth *earth=new Earth();
    
    U4DEngine::U4DGameModelInterface *model=new GameLogic();
    
    //U4DEngine::U4DControllerInterface *control=new GameController();

    U4DEngine::U4DControllerInterface *control=new GamePadController();
    
    setGameWorldControllerAndModel(earth, control, model);
    
}
