//
//  MenuWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "MenuWorld.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DVector3n.h"
#include "U4DResourceLoader.h"
#include "U4DLayerManager.h"


MenuWorld::MenuWorld(){
    
}

MenuWorld::~MenuWorld(){
    
}

void MenuWorld::init(){
    
    setupConfiguration();
    
    //The U4DResourceLoader is in charge of loading the binary file containing the scene data
    U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();
    
    //Load binary file with scene data
    resourceLoader->loadSceneData("menuscene.u4d");
    
    //Load binary file with texture data
    resourceLoader->loadTextureData("soccerTextures.u4d");
    
    //load binary file with animation data
    resourceLoader->loadAnimationData("walkingAnimation.u4d");
    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

    //set this view to the layer Manager
    layerManager->setWorld(this);

    //create Layers
    mainMenuLayer=new MainMenuLayer("menuLayer");
    
    mainMenuLayer->init();
    
    layerManager->addLayerToContainer(mainMenuLayer);

    //push layer
    layerManager->pushLayer("menuLayer");
    
    changeState(selectingOptionsInMenu);
    
}

void MenuWorld::selectOptionInMenu(int uValue){
    
    mainMenuLayer->selectOptionInMenu(uValue);
    
}

void MenuWorld::playOption(){
    
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();
    
    playMenuLayer=new PlayMenuLayer("playMenuLayer");
    
    playMenuLayer->init();
    
    layerManager->addLayerToContainer(playMenuLayer);
    
    //push layer
    layerManager->pushLayer("playMenuLayer");
    
    changeState(selectingKit);
    
}

void MenuWorld::selectKit(int uValue){
    
    playMenuLayer->selectKit(uValue); 
    
}

void MenuWorld::removeActiveLayer(){
    
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();
    
    U4DEngine::U4DLayer *activeLayer=layerManager->getActiveLayer();
    
    layerManager->popLayer();
    
    delete activeLayer;
    
    changeState(selectingOptionsInMenu);
    
}

void MenuWorld::update(double dt){
    
}

//Sets the configuration for the engine: Perspective view, shadows, light
void MenuWorld::setupConfiguration(){
    
    //Get director object
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.01f, 400.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-100.0f, 100.0f, -100.0f, 100.0f, -100.0f, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPosition(0.0,2.0,-7.0);
    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DEngine::U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DEngine::U4DLights *light=U4DEngine::U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,-5.0);
    U4DEngine::U4DVector3n diffuse(0.9,0.9,0.9);
    U4DEngine::U4DVector3n specular(0.2,0.2,0.2);
    light->setDiffuseColor(diffuse);
    light->setSpecularColor(specular);
    
    addChild(light);
    
    //Set the view direction of the camera and light
    //camera->viewInDirection(origin);
    
    light->viewInDirection(origin);
    
    //set the poly count to 5000. Default is 3000
    director->setPolycount(5000);
    
}

void MenuWorld::setState(int uState){
    state=uState;
}

int MenuWorld::getState(){
    return state;
}

void MenuWorld::changeState(int uState){
    
    //set new state
    setState(uState);
    
    switch (uState) {
         
        case selectingOptionsInMenu:
            
            break;
            
        case selectingKit:
            
            break;
        
        default:
            break;
    }
    
}
