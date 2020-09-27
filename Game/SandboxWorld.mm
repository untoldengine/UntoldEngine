//
//  SandboxWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "SandboxWorld.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DResourceLoader.h"
#include "SandboxLogic.h"

#include "U4DSlider.h"
#include "U4DWindow.h"
#include "U4DJoystick.h"
#include "U4DSkybox.h"
#include "U4DLayerManager.h"
#include "U4DLayer.h"
#include "U4DCallback.h"

using namespace U4DEngine;

SandboxWorld::SandboxWorld():showCollisionVolume(false),showNarrowVolume(false){
    
}

SandboxWorld::~SandboxWorld(){
    
}

void SandboxWorld::init(){
    
    /*----DO NOT REMOVE. THIS IS REQUIRED-----*/
    //Configures the perspective view, shadows, lights and camera.
    setupConfiguration();
    /*----END DO NOT REMOVE.-----*/
    
    //The following code snippets loads scene data, renders the characters and skybox.
    
    /*---LOAD SCENE ASSETS HERE--*/
    //Load binary file with scene data
    U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();

    resourceLoader->loadSceneData("soccergame.u4d");

    //Load binary file with texture data
   resourceLoader->loadTextureData("soccerTextures.u4d");
    
   resourceLoader->loadFontData("uiFont.u4d");
    
    
    //render the ground
    U4DEngine::U4DGameObject *ground=new U4DEngine::U4DGameObject();

    if(ground->loadModel("field")){

        //ground->setShader("vertexFieldShader", "fragmentFieldShader");


        //set shadows
        ground->setEnableShadow(true);

        ground->setNormalMapTexture("FieldNormalMap.png");

        //send info to gpu
        ground->loadRenderingInformation();

        //add to scenegraph
        addChild(ground);
    }

    player=new U4DEngine::U4DGameObject();

    if (player->loadModel("player0")) {

        player->setEnableShadow(true);

        player->enableCollisionBehavior();

        player->loadRenderingInformation();

        addChild(player);
    }

    U4DEngine::U4DGameObject *ads[5];

    for(int i=0;i<sizeof(ads)/sizeof(ads[0]);i++){

        std::string name="ad";

        name+=std::to_string(i);

        ads[i]=new U4DEngine::U4DGameObject();

        if(ads[i]->loadModel(name.c_str())){

            ads[i]->setEnableShadow(true);

            ads[i]->loadRenderingInformation();

            addChild(ads[i]);
        }

    }

    U4DEngine::U4DGameObject *bleachers[11];

    for(int i=0;i<sizeof(bleachers)/sizeof(bleachers[0]);i++){

        std::string name="bleacher";

        name+=std::to_string(i);

        bleachers[i]=new U4DEngine::U4DGameObject();

        if(bleachers[i]->loadModel(name.c_str())){

            bleachers[i]->setEnableShadow(true);

            bleachers[i]->loadRenderingInformation();

            addChild(bleachers[i]);
        }

    }
    

    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

    //set this view (U4DWorld subclass) to the layer Manager
    layerManager->setWorld(this);

    //create Layers
    U4DEngine::U4DLayer* mainMenuLayer=new U4DEngine::U4DLayer("menuLayer");

    U4DEngine::U4DWindow *uiWindow=new U4DEngine::U4DWindow("windowA", -0.5, 0.0, 300.0, 400.0, "My Window", "uiFont");
    
    //Create buttons to add to the layer
    buttonA=new U4DEngine::U4DButton("buttonA",-0.7,0.3,50.0,20.0,"hi","uiFont");
   
    sliderA=new U4DEngine::U4DSlider("sliderA",-0.7,0.2,80.0,20.0,"Pos x","uiFont");
    sliderB=new U4DEngine::U4DSlider("sliderB",-0.7,0.0,80.0,20.0,"Pos y","uiFont");
    
    checkbox=new U4DEngine::U4DCheckbox("checkbox",-0.7,0.4,20.0,20.0,"Show Broad Volume","uiFont");
    
    checkboxB=new U4DEngine::U4DCheckbox("checkboxB",-0.7,0.5,20.0,20.0,"Show Convex Hull","uiFont");
    
    //joystickA=new U4DEngine::U4DJoystick("joystick",-0.7,-0.3,"joyStickBackground.png",90.0,90.0,"joystickDriver.png");
    joystickA=new U4DEngine::U4DJoystick("joystick",-0.7,-0.3,90.0,90.0);
    
//    //create a callback
//    U4DEngine::U4DCallback<SandboxWorld>* buttonACallback=new U4DEngine::U4DCallback<SandboxWorld>;
//
//    buttonACallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnButtonA);
//
//    buttonA->setCallbackAction(buttonACallback);
//
    //create a callback
    U4DEngine::U4DCallback<SandboxWorld>* sliderACallback=new U4DEngine::U4DCallback<SandboxWorld>;

    sliderACallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnSlider);

    sliderA->setCallbackAction(sliderACallback);
    
    U4DEngine::U4DCallback<SandboxWorld>* sliderBCallback=new U4DEngine::U4DCallback<SandboxWorld>;

    sliderBCallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnSliderB);

    sliderB->setCallbackAction(sliderBCallback);
//
    //create a callback
    U4DEngine::U4DCallback<SandboxWorld>* joystickCallback=new U4DEngine::U4DCallback<SandboxWorld>;

    joystickCallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnJoystick);

    joystickA->setCallbackAction(joystickCallback);
    
    //create a callback
    U4DEngine::U4DCallback<SandboxWorld>* checkboxCallback=new U4DEngine::U4DCallback<SandboxWorld>;
    
    checkboxCallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnCheckbox);
    
    checkbox->setCallbackAction(checkboxCallback);
    
    //create a callback
    U4DEngine::U4DCallback<SandboxWorld>* checkboxBCallback=new U4DEngine::U4DCallback<SandboxWorld>;
    
    checkboxBCallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnCheckboxB);
    
    checkboxB->setCallbackAction(checkboxBCallback);
    
    

    
    //add the buttons to the layer
    
    mainMenuLayer->addChild(buttonA);
    mainMenuLayer->addChild(sliderA);
    mainMenuLayer->addChild(joystickA);
    mainMenuLayer->addChild(checkbox);
    mainMenuLayer->addChild(sliderB);
    mainMenuLayer->addChild(checkboxB);
    
    mainMenuLayer->addChild(uiWindow);
    
    layerManager->addLayerToContainer(mainMenuLayer);

    //push layer
    layerManager->pushLayer("menuLayer");
    
    

}

void SandboxWorld::actionOnButtonA(){
    
    if(buttonA->getIsPressed()){
        
        
    }else if (buttonA->getIsReleased()){
        
        
    }
    
}

void SandboxWorld::actionOnSlider(){
    
    if(sliderA->getIsActive()){
        
        //player->translateBy(sliderA->dataValue, 0.0, 0.0);
        
    }else if (sliderA->getIsReleased()){
        
        
    }
    
}

void SandboxWorld::actionOnSliderB(){
    
    if(sliderB->getIsActive()){
        
        //player->translateBy(0.0,0.0,sliderB->dataValue);
        
    }else if (sliderA->getIsReleased()){
        
        
    }
    
}

void SandboxWorld::actionOnJoystick(){
    
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    
    if (joystickA->getIsActive()) {
        
        camera->translateBy(0.0,joystickA->dataPosition.y,joystickA->dataPosition.x);
        
    }else{
    
        
    }
    
}

void SandboxWorld::actionOnCheckbox(){
    
    
    if (checkbox->getIsPressed()) {
        
        //showCollisionVolume=!showCollisionVolume;
       // setEnableGrid(showCollisionVolume);
        //player->setBroadPhaseBoundingVolumeVisibility(showCollisionVolume);
    }
    
}

void SandboxWorld::actionOnCheckboxB(){
    
    
    if (checkboxB->getIsPressed()) {
        
        //showNarrowVolume=!showNarrowVolume;
       
       // player->setNarrowPhaseBoundingVolumeVisibility(showNarrowVolume);
    }
    
}

void SandboxWorld::update(double dt){
 
}

//Sets the configuration for the engine: Perspective view, shadows, light
void SandboxWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.01f, 400.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-100.0f, 100.0f, -100.0f, 100.0f, -100.0f, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPosition(0.0,25.0,-50.0);
    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(50.0,50.0,-50.0);
    U4DEngine::U4DVector3n diffuse(0.5,0.5,0.5);
    U4DEngine::U4DVector3n specular(0.2,0.2,0.2);
    light->setDiffuseColor(diffuse);
    light->setSpecularColor(specular);
    
    addChild(light);
    
    //Set the view direction of the camera and light
    camera->viewInDirection(origin);
    
    light->viewInDirection(origin);
    
    //set the poly count to 5000. Default is 3000
    director->setPolycount(5000);
}
