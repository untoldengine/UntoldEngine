//
//  StartMenu.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "StartMenu.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DLayerManager.h"
#include "LevelOneScene.h"
#include "U4DSceneManager.h"
#include "U4DCallback.h"
#include "U4DResourceLoader.h"


using namespace U4DEngine;

StartMenu::StartMenu():menuInstructions(nullptr){
    
}

StartMenu::~StartMenu(){
    
    delete menuLayer;
    delete menuInstructions;
    
}

void StartMenu::init(){
    
    setupConfiguration();
    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

    //set this view to the layer Manager
    layerManager->setWorld(this);

    //create Layer
    menuLayer=new U4DEngine::U4DLayer("menuLayer");

    //create buttons as children of layer

    menuLayer->setBackgroundImage("futbolstartscreen.png");

    //Create the UI Elements
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    if (director->getDeviceOSType()==U4DEngine::deviceOSIOS) {
//        startButton=new U4DEngine::U4DButton("buttonA",0.0,-0.5,103.0,103.0,"ButtonA.png","ButtonAPressed.png");
//
//        menuLayer->addChild(startButton);
        
    }else{
        
        //load up text
        
        
        //3. Create a text object. Provide the font loader object and the spacing between letters
        menuInstructions=new U4DEngine::U4DText("gameFont");
        
        if(director->getGamePadControllerPresent()){
            
            //Game controller detected
            
            menuInstructions->setText("Press X");
            //5. If desire, set the text position. Remember the coordinates for 2D objects, such as text is [-1.0,1.0]
            menuInstructions->translateTo(-0.15, -0.50, 0.0);
            
        }else{
            
            //keyboard detected
            
            menuInstructions->translateTo(-0.2, -0.50, 0.0);
            menuInstructions->setText("PRESS SPACE");
            
        }


        //6. Add the text to the scenegraph
        menuLayer->addChild(menuInstructions,-2);
        
    }
    
    layerManager->addLayerToContainer(menuLayer);

    //push layer
    layerManager->pushLayer("menuLayer");
    
    
}


void StartMenu::update(double dt){
    
}

//Sets the configuration for the engine: Perspective view, shadows, light
void StartMenu::setupConfiguration(){
    

}
