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

SandboxWorld::SandboxWorld():showAnimation(false),showParticles(false){
    
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

    //The spaceScene.u4d file contains the data for the astronaut model and island
    //All of the .u4d files are found in the Resource folder. Note, you will need to use the Digital Asset Converter tool to convert all game asset data into .u4d files. For more info, go to www.untoldengine.com.
    resourceLoader->loadSceneData("spaceScene.u4d");

    //Load binary file with texture data for the astronaut
    resourceLoader->loadTextureData("spaceTextures.u4d");
    
    //load ui textures contains images that can be used for the UIs. Look at the joystick instance below.
    resourceLoader->loadTextureData("uiTextures.u4d");
    
    //load particle data
    resourceLoader->loadParticleData("redBulletEmitter.u4d");
    
    //Load binary file with animation data
    resourceLoader->loadAnimationData("astronautWalkAnim.u4d");
    
    //load font data. In this example, the font is used for the UIs.
    resourceLoader->loadFontData("uiFont.u4d");
    
    
    //Create an instance of U4DGameObject type
    myAstronaut=new U4DEngine::U4DGameObject();

    //Load attribute (rendering information) into the game entity
    if (myAstronaut->loadModel("astronaut")) {

        myAstronaut->setEnableShadow(true);
        
        myAstronaut->setNormalMapTexture("astronautNormalMap.png");
        
        myAstronaut->enableKineticsBehavior();
        
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        
        myAstronaut->setGravity(zero);
        
        myAstronaut->enableCollisionBehavior();
        
        //Line 4. Load rendering information into the GPU
        myAstronaut->loadRenderingInformation();

        //Line 5. Add astronaut to the scenegraph
        addChild(myAstronaut);
        
        //store original position
        originalPosition=myAstronaut->getAbsolutePosition();

    }
    
    // Create an Animation object and link it to the 3D model
    walkAnimation=new U4DEngine::U4DAnimation(myAstronaut);

    //Load animation data into the animation object
    if(myAstronaut->loadAnimationToModel(walkAnimation, "walking")){

        //If animation data was successfully loaded, you can set other parameters here. For now, we won't do this.

    }

    
    //Create an instance of U4DGameObject type
    U4DEngine::U4DGameObject *island=new U4DEngine::U4DGameObject();

    //Line 3. Load attribute (rendering information) into the game entity
    if (island->loadModel("island")) {

        island->setEnableShadow(true);
        
        //Line 4. Load rendering information into the GPU
        island->loadRenderingInformation();

        //Line 5. Add astronaut to the scenegraph
        addChild(island);

    }
    
    //Create a particle system
    particleSystem=new U4DEngine::U4DParticleSystem();

    //3.Load the particle's attributes file and particle texture into the Particle System entity
    if(particleSystem->loadParticle("redBulletEmitter")){

        //4. load the attributes into the GPU
        particleSystem->loadRenderingInformation();

        //5.add the particle system to the scenegraph. If you are using a Skybox, make sure to set the proper order of the particle system in the scenegraph. In this instance,
        //I set the order to -5
        addChild(particleSystem,-5);

        particleSystem->translateBy(1.0, 0.5, 0.0);

        
    }
    
    //Render a skybox
    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();
    
    //initialize the skybox
    skybox->initSkyBox(20.0,"LeftImage.png","RightImage.png","TopImage.png","BottomImage.png","FrontImage.png", "BackImage.png");

    //add the skybox to the scenegraph with appropriate z-depth
    addChild(skybox);
    
    
    //If you want UI elements, you need to create a layer and make each UI a child of the layer.
    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

    //set this view (U4DWorld subclass) to the layer Manager
    layerManager->setWorld(this);

    //create Layers
    U4DEngine::U4DLayer* mainMenuLayer=new U4DEngine::U4DLayer("menuLayer");

    //create UIs
    U4DEngine::U4DWindow *uiWindow=new U4DEngine::U4DWindow("windowA", -0.5, 0.3, 300.0, 270.0, "My Window", "uiFont");
    
    //Create buttons to add to the layer
    sliderA=new U4DEngine::U4DSlider("sliderA",-0.7,0.5,80.0,20.0,"Pos x","uiFont");
    sliderB=new U4DEngine::U4DSlider("sliderB",-0.7,0.35,80.0,20.0,"Pos z","uiFont");
    
    checkbox=new U4DEngine::U4DCheckbox("checkboxA",-0.8,0.2,20.0,20.0,"Show Broad Volume","uiFont");
    
    checkboxB=new U4DEngine::U4DCheckbox("checkboxB",-0.8,0.1,20.0,20.0,"Show Convex Hull","uiFont");
    
    checkboxC=new U4DEngine::U4DCheckbox("checkboxC",-0.8,0.0,20.0,20.0,"Animate","uiFont");
    
    checkboxD=new U4DEngine::U4DCheckbox("checkboxD",-0.8,-0.1,20.0,20.0,"Particles","uiFont");
    
    //You can use UIs with images also
    joystickA=new U4DEngine::U4DJoystick("joystick",-0.25,0.1,"joyStickBackground.png",90.0,90.0,"joyStickDriver.png");
    
    //or without images
    //joystickA=new U4DEngine::U4DJoystick("joystick",-0.25,0.1,90.0,90.0);
    
    buttonA=new U4DEngine::U4DButton("buttonA",-0.25,0.5,50.0,20.0,"Reset","uiFont");
    
    //UI elements can have callbacks if you want. If not, all messages are sent to the Logic component. In this case, to "SandboxLogic". Look into receiveUserInputUpdate() method.
    
    //create a callback for button A
    U4DEngine::U4DCallback<SandboxWorld>* buttonACallback=new U4DEngine::U4DCallback<SandboxWorld>;

    buttonACallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnButtonA);

    buttonA->setCallbackAction(buttonACallback);
    
    //create a callback for checkbox C
    U4DEngine::U4DCallback<SandboxWorld>* checkboxCCallback=new U4DEngine::U4DCallback<SandboxWorld>;
    
    checkboxCCallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnCheckboxC);
    
    checkboxC->setCallbackAction(checkboxCCallback);
    
    //create a callback for checkbox D
    U4DEngine::U4DCallback<SandboxWorld>* checkboxDCallback=new U4DEngine::U4DCallback<SandboxWorld>;
    
    checkboxDCallback->scheduleClassWithMethod(this, &SandboxWorld::actionOnCheckboxD);
    
    checkboxD->setCallbackAction(checkboxDCallback);
    
    //add the buttons to the layer
    mainMenuLayer->addChild(buttonA);
    mainMenuLayer->addChild(sliderA);
    mainMenuLayer->addChild(joystickA);
    mainMenuLayer->addChild(checkbox);
    mainMenuLayer->addChild(sliderB);
    mainMenuLayer->addChild(checkboxB);
    mainMenuLayer->addChild(checkboxC);
    mainMenuLayer->addChild(checkboxD);
    mainMenuLayer->addChild(uiWindow);
    
    layerManager->addLayerToContainer(mainMenuLayer);

    //push layer
    layerManager->pushLayer("menuLayer");
    
}

void SandboxWorld::actionOnButtonA(){
    
    if(buttonA->getIsPressed()){
    
    }else if (buttonA->getIsReleased()){
        
         myAstronaut->translateTo(originalPosition);
    }
    
}

void SandboxWorld::actionOnCheckboxC(){
    
    if (checkboxC->getIsPressed() && walkAnimation!=nullptr) {
        
        showAnimation=!showAnimation;
        
        if (showAnimation==true) {

            walkAnimation->play();
            
        }else{
            walkAnimation->stop();
        }
    }
    
}

void SandboxWorld::actionOnCheckboxD(){
    
    if (checkboxD->getIsPressed() && particleSystem!=nullptr) {
        
        showParticles=!showParticles;
        
        if (showParticles==true) {

            particleSystem->play();
            
        }else{
            particleSystem->stop();
        }
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
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-30.0f, 30.0f, -30.0f, 30.0f, -30.0f, 30.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPosition(0.0,3.0,-5.0);
    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(10.0,10.0,-10.0);
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
