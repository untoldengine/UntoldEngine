//
//  LevelOneWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "LevelOneWorld.h"
#include <stdio.h>
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DSkybox.h"
#include "U4DResourceLoader.h"
#include "U4DFontLoader.h"
#include "U4DLayerManager.h"
#include "U4DText.h"
#include "U4DLogger.h"
#include "UserCommonProtocols.h"
#include "U4DCameraInterface.h"
#include "U4DCameraThirdPerson.h"
#include "U4DCameraFirstPerson.h"
#include "U4DCameraBasicFollow.h"
#include "Weapon.h"
#include "MobileLayer.h"
#include "U4DParticleSystem.h"
#include "Meteor.h"

using namespace U4DEngine;

void LevelOneWorld::init(){
    
    /*----DO NOT REMOVE. THIS IS REQUIRED-----*/
    //Configures the perspective view, shadows, lights and camera.
    setupConfiguration();
    /*----END DO NOT REMOVE.-----*/
    
    //The following code snippets loads scene data, renders the characters and skybox.
    
    /*---LOAD SCENE ASSETS HERE--*/
    //The U4DResourceLoader is in charge of loading the binary file containing the scene data
    U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();
    
    //Load binary file with scene data
    resourceLoader->loadSceneData("gamescene.u4d");
    
    //Load binary file with texture data
    resourceLoader->loadTextureData("gameTextures.u4d");
    
    //load binary file with animation data
    
    //Animation for astronaut
    resourceLoader->loadAnimationData("idle.u4d");
        
    resourceLoader->loadAnimationData("patrol.u4d");
    
    resourceLoader->loadAnimationData("shoot.u4d");
    
    //Animation for alien
    resourceLoader->loadAnimationData("aliendead.u4d");

    resourceLoader->loadAnimationData("alienpatrol.u4d");
    
    resourceLoader->loadAnimationData("alienidle.u4d");
    
    //load particle data
    resourceLoader->loadParticleData("redBulletEmitter.u4d");
    
    resourceLoader->loadParticleData("fireparticles.u4d");
    
    resourceLoader->loadParticleData("asteroidparticles.u4d");
    
    //RENDER THE MODELS
    
    //render the ground
    ground=new U4DEngine::U4DGameObject();

    if(ground->loadModel("ground")){

        //set shadows
        ground->setEnableShadow(true);

        ground->enableMeshManager(2);
        
        //send info to gpu
        ground->loadRenderingInformation();

        //add to scenegraph
        addChild(ground);
    }
    
    
    //Render the house objects
    

    //This is a nice way to load identical models. For example, the names of the models in blender are house0, house1
    //house2, etc. Instead of loading it one by one, you can simply append the "i" count to the "house" text.
    for(int i=0;i<sizeof(stones)/sizeof(stones[0]);i++){

        std::string name="stone";

        name+=std::to_string(i);

        stones[i]=new U4DEngine::U4DGameObject();

        if(stones[i]->loadModel(name.c_str())){

            stones[i]->setEnableShadow(true);

            stones[i]->loadRenderingInformation();

            addChild(stones[i]);
        }

    }
    
    //Render the house objects
    

    //This is a nice way to load identical models. For example, the names of the models in blender are house0, house1
    //house2, etc. Instead of loading it one by one, you can simply append the "i" count to the "house" text.
    for(int i=0;i<sizeof(trees)/sizeof(trees[0]);i++){

        std::string name="tree";

        name+=std::to_string(i);

        trees[i]=new U4DEngine::U4DGameObject();

        if(trees[i]->loadModel(name.c_str())){

            trees[i]->setEnableShadow(true);

            trees[i]->loadRenderingInformation();

            addChild(trees[i]);
        }

    }

    //create the player object and render it
    
    astronaut0=new Player();
    
    if(astronaut0->init("astronaut0")){
        
        //change state of main player
        astronaut0->changeState(patrolidle);
        
        //add it to the scenegraph
        addChild(astronaut0);
        
        astronaut0->setMap(ground);
        
    }
    
    
    //add the pistol
    Weapon *pistol=new Weapon();

    if(pistol->init("gun")){

        astronaut0->setWeapon(pistol);

    }
    
    
    //uncomment to have second astronaut in the game
//    astronaut1=new Player();
//
//    if(astronaut1->init("astronaut1")){
//
//        //add it to the scenegraph
//        addChild(astronaut1);
//
//        astronaut1->setMap(ground);
//
//        //set astronaut to follow
//        astronaut1->setLeader(astronaut0);
//
//        astronaut1->changeState(navigate);
//    }
    
    lander=new U4DEngine::U4DGameObject();

    if(lander->loadModel("ApolloLander")){

        //set shadows
        lander->setEnableShadow(true);

        //send info to gpu
        lander->loadRenderingInformation();

        //add to scenegraph
        addChild(lander);
    }
    
    
    //Create particles
    
    //2. Create a particle system
    U4DEngine::U4DParticleSystem *particleSystem=new U4DEngine::U4DParticleSystem();

    //3.Load the particle's attributes file and particle texture into the Particle System entity
    if(particleSystem->loadParticle("asteroidparticles")){

        //4. load the attributes into the GPU
        particleSystem->loadRenderingInformation();

        //5.add the particle system to the scenegraph. If you are using a Skybox, make sure to set the proper order of the particle system in the scenegraph. In this instance,
        //I set the order to -5
        addChild(particleSystem,-20);
        
        particleSystem->translateTo(0.0, 0.0, -15.0);
        
//        particleSystem->setEnableNoise(true); //set false by default
//        particleSystem->setNoiseDetail(2.0); //ranges from [2-16]

        //6. initiate the particle's emission
        particleSystem->play();

    }
    
    //Asteroids
    Meteor *meteors[3];
    
    for(int i=0;i<sizeof(meteors)/sizeof(meteors[0]);i++){

        std::string name="meteor";

        name+=std::to_string(i);

        meteors[i]=new Meteor();

        if(meteors[i]->init(name.c_str())){

            meteors[i]->setMap(ground);
            
            addChild(meteors[i]);
            
            meteors[i]->changeState(shooting);
        }

    }
    
    
    /*---CREATE SKYBOX HERE--*/
    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();

    skybox->initSkyBox(20.0,"spacemarsLF.png","spacemarsRT.png","spacemarsUP.png","spacemarsDN.png","spacemarsFT.png", "spacemarsBK.png");

    skybox->translateBy(0.0,20.0,0.0);

    addChild(skybox,0);

    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    if (director->getDeviceOSType()==U4DEngine::deviceOSIOS) {

        //Create Mobile Layer with buttons & joystic
        U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

        //set the world (view component) for the layer manager --MAY WANT TO FIX THIS. DONT LIKE SETTING THE VIEW HERE FOR THE LAYER MANAGER
        layerManager->setWorld(this);

        //create the Mobile Layer
        MobileLayer *mobileLayer=new MobileLayer("mobilelayer");

        mobileLayer->init();

        mobileLayer->setPlayer(astronaut0);

        layerManager->addLayerToContainer(mobileLayer);

        layerManager->pushLayer("mobilelayer");

    }else if(director->getDeviceOSType()==U4DEngine::deviceOSMACX){

        /*---CREATE TEXT HERE--*/
        //Create a Font Loader object
        U4DEngine::U4DFontLoader *fontLoader=new U4DEngine::U4DFontLoader();

        //Load font data into the font loader object. Such as the xml file and image file
        fontLoader->loadFontAssetFile("myFont.xml", "myFont.png");

        //Create a text object. Provide the font loader object and the spacing between letters
        U4DEngine::U4DText *myText=new U4DEngine::U4DText(fontLoader, 30);

        //set the text you want to display
        myText->setText("exit: cmd+w");

        //If desire, set the text position. Remember the coordinates for 2D objects, such as text is [-1.0,1.0]
        myText->translateTo(0.50, -0.90, 0.0);

        //6. Add the text to the scenegraph
        addChild(myText,-2);

    }
    
    /*---SET CAMERA BEHAVIOR TO THIRD PERSON--*/
    //Instantiate the camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    //Line 1. Instantiate the camera interface and the type of camera you desire
    U4DEngine::U4DCameraInterface *cameraThirdPerson=U4DEngine::U4DCameraThirdPerson::sharedInstance();

    //Line 2. Set the parameters for the camera. Such as which model the camera will target, and the offset positions
    cameraThirdPerson->setParameters(astronaut0,0.0,2.0,10.0);

    //Line 3. set the camera behavior
    camera->setCameraBehavior(cameraThirdPerson);

    //Instantiate the camera
//    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
//
//    //Line 1. Instantiate the camera interface and the type of camera you desire
//    U4DEngine::U4DCameraInterface *cameraFirstPerson=U4DEngine::U4DCameraFirstPerson::sharedInstance();
//
//    //Line 2. Set the parameters for the camera. Such as which model the camera will target, and the offset positions
//    cameraFirstPerson->setParameters(astronaut0,0.0,0.5,0.5);
//
//    //Line 3. set the camera behavior
//    camera->setCameraBehavior(cameraFirstPerson);
    
}

void LevelOneWorld::update(double dt){
    
    
}

void LevelOneWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.01f, 100.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-30.0f, 30.0f, -30.0f, 30.0f, -30.0f, 30.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPosition(0.0,10.0,-30.0);
    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(10.0,10.0,-10.0);
    U4DEngine::U4DVector3n diffuse(0.9,0.2,0.2);
    U4DEngine::U4DVector3n specular(0.2,0.0,0.0);
    light->setDiffuseColor(diffuse);
    light->setSpecularColor(specular);
    
    addChild(light);
    
    //Set the view direction of the camera and light
    camera->viewInDirection(origin);
    
    light->viewInDirection(origin);
    
    //set the poly count to 5000. Default is 3000
    director->setPolycount(5000);
    
}

LevelOneWorld::~LevelOneWorld(){
    
    //remove all objects from the scenegraph
    removeChild(astronaut0);
    removeChild(astronaut1);
    removeChild(ground);
    removeChild(lander);
    
    
    delete astronaut0;
    delete astronaut1;
    delete ground;
    delete lander;
    
    
    for (int i=0; i<31; i++) {
        removeChild(stones[i]);
        delete stones[i];
    }

    for (int i=0; i<28; i++) {
        removeChild(trees[i]);
        delete trees[i];
    }
    std::cout<<"objects deleted"<<std::endl;
    
}




