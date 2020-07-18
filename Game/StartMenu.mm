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

StartMenu::StartMenu(){
    
}

StartMenu::~StartMenu(){
    
    delete menuLayer;
    delete playButton;
    delete quitButton;
    
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

    menuLayer->setBackgroundImage("gamestartimage.png");

    //Create the UI Elements
    playButton=new U4DEngine::U4DButton("start",0.6,-0.4,150.0,61.0,"start.png","startPressed.png");
    quitButton=new U4DEngine::U4DButton("quit",0.6,-0.75,150.0,61.0,"quit.png","quitPressed.png");

    //Create the callback for button
    U4DEngine::U4DCallback<StartMenu>* playButtonCallback=new U4DEngine::U4DCallback<StartMenu>;

    playButtonCallback->scheduleClassWithMethod(this, &StartMenu::play);

    playButton->setCallbackAction(playButtonCallback);

    //add button to the layer

    menuLayer->addChild(playButton);
    menuLayer->addChild(quitButton);

    layerManager->addLayerToContainer(menuLayer);

    //push layer
    layerManager->pushLayer("menuLayer");
    
    
}

void StartMenu::play(){
    
    //change scene
    if (playButton->getIsReleased()) {
        
        //get instance of scene manager
        U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();

        LevelOneScene *levelOneScene=new LevelOneScene();

        sceneManager->changeScene(levelOneScene);
        
    }
    
}

void StartMenu::update(double dt){
    
}

//Sets the configuration for the engine: Perspective view, shadows, light
void StartMenu::setupConfiguration(){
    

}
