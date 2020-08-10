//
//  LevelOneUILayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "LevelOneUILayer.h"
#include "U4DLayerManager.h"
#include "U4DCallback.h"
#include "UserCommonProtocols.h"

LevelOneUILayer::LevelOneUILayer(std::string uLayerName):U4DLayer(uLayerName){
    
}

LevelOneUILayer::~LevelOneUILayer(){
    
}

void LevelOneUILayer::init(){
    
    //Create UI Elements
    
    //create the Joystick
    joystick=new U4DEngine::U4DJoyStick("joystick",-0.7,-0.6,"joyStickBackground.png",130.0,130.0,"joystickDriver.png",80.0,80.0);
    
    //create the buttons
    buttonA=new U4DEngine::U4DButton("buttonA",0.4,-0.6,103.0,103.0,"ButtonA.png","ButtonAPressed.png");
    buttonB=new U4DEngine::U4DButton("buttonB",0.7,-0.6,103.0,103.0,"ButtonB.png","ButtonBPressed.png");
    
    addChild(joystick);
    addChild(buttonA);
    addChild(buttonB);
    
}



