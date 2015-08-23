//
//  MainScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "MainScene.h"
#include "Earth.h"
#include "GameController.h"
#include "GameLogic.h"
#include "U4DGameModelInterface.h"
#include "U4DTouchesController.h"

void MainScene::init(){
    
    Earth *earth=new Earth();
    U4DEngine::U4DGameModelInterface *model=new GameLogic();
    U4DEngine::U4DControllerInterface *control=new GameController();
    
    setGameWorldControllerAndModel(earth, control, model);
    
    earth->action();
     
}