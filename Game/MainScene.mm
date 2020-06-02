//
//  MainScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "MainScene.h"
#include "Earth.h"
#include "GameLogic.h"
#include "U4DGameModelInterface.h"
#include "U4DTouchesController.h"
#include "U4DGamepadController.h"
#include "U4DKeyboardController.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"

MainScene::MainScene(){}

MainScene::~MainScene(){}

void MainScene::init(){
    
    Earth *earth=new Earth();
    
    U4DEngine::U4DGameModelInterface *model=new GameLogic();
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::U4DControllerInterface *control = nullptr;
    
    if(director->getDeviceOSType()==U4DEngine::deviceOSIOS){
        
        control=new U4DEngine::U4DTouchesController();
        
    }else if(director->getDeviceOSType()==U4DEngine::deviceOSMACX){
        
        if(director->getGamePadControllerPresent()){
            
            //Game controller detected
            control=new U4DEngine::U4DGamepadController();
            
        }else{
            
            //enable keyboard control
            control=new U4DEngine::U4DKeyboardController();
            
        }
        
    }
    

    setGameWorldControllerAndModel(earth, control, model);
    
}
