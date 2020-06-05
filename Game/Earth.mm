//
//  Earth.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "Earth.h"
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
#include "U4DCameraFirstPerson.h"
#include "Weapon.h"
#include "MobileLayer.h"

using namespace U4DEngine;

void Earth::init(){
    
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
    resourceLoader->loadAnimationData("running.u4d");
    
    resourceLoader->loadAnimationData("patroling.u4d");
    
    resourceLoader->loadAnimationData("patrolingidle.u4d");
    
    resourceLoader->loadAnimationData("dead.u4d");
    
    //load particle data
    resourceLoader->loadParticleData("redBulletEmitter.u4d");
    
    //RENDER THE MODELS
    
    //render the ground
    U4DEngine::U4DGameObject *ground=new U4DEngine::U4DGameObject();

    if(ground->loadModel("ground")){

        //set shadows
        ground->setEnableShadow(true);

        //send info to gpu
        ground->loadRenderingInformation();

        //add to scenegraph
        addChild(ground);
    }
    
    
    //renders the map level
    U4DEngine::U4DGameObject *map=new U4DEngine::U4DGameObject();

    if(map->loadModel("map")){

        //set the map to invisible.
        map->setShader("vertexNonVisibleShader","fragmentNonVisibleShader");
        
        //We just want the map for raycasting purposes
        map->enableMeshManager(2);
        
        map->loadRenderingInformation();

        addChild(map);
    }
    
    
    //Render the house objects
    U4DEngine::U4DGameObject *houses[6];

    //This is a nice way to load identical models. For example, the names of the models in blender are house0, house1
    //house2, etc. Instead of loading it one by one, you can simply append the "i" count to the "house" text.
    for(int i=0;i<sizeof(houses)/sizeof(houses[0]);i++){

        std::string name="house";

        name+=std::to_string(i);

        houses[i]=new U4DEngine::U4DGameObject();

        if(houses[i]->loadModel(name.c_str())){

            houses[i]->setEnableShadow(true);

            houses[i]->loadRenderingInformation();

            addChild(houses[i]);
        }

    }

    //create the player object and render it
    
    player=new Player();
    
    if(player->init("player")){
        
        //add it to the scenegraph
        addChild(player);
        
    }
    
    
    //add the pistol
    Weapon *pistol=new Weapon();
    
    if(pistol->init("pistol")){
                
        player->setWeapon(pistol); 
        
    }
    
    //add map level to player
    player->setMap(map);
    
    //change state of main player
    player->changeState(patrolidle);
    
    //add the enemies
    Player *enemy[3];

    for(int i=0;i<sizeof(enemy)/sizeof(enemy[0]);i++){

        std::string name="enemy";
        name+=std::to_string(i);

        enemy[i]=new Player();

        if (enemy[i]->init(name.c_str())) {

            enemy[i]->setHero(player);

            enemy[i]->rotateBy(0.0,180.0,0.0);

            addChild(enemy[i]);

            enemy[i]->changeState(attack);
        }

    }
    
    /*---CREATE SKYBOX HERE--*/
    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();

    skybox->initSkyBox(20.0,"LeftImage.png","RightImage.png","TopImage.png","BottomImage.png","FrontImage.png", "BackImage.png");

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
        
        mobileLayer->setPlayer(player);
        
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
        myText->translateTo(0.30, -0.90, 0.0);

        //6. Add the text to the scenegraph
        addChild(myText,-2);
        
    }
    
    /*---SET CAMERA BEHAVIOR TO FIRST PERSON--*/
    //Instantiate the camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    //Line 1. Instantiate the camera interface and the type of camera you desire
    U4DEngine::U4DCameraInterface *cameraFirstPerson=U4DEngine::U4DCameraFirstPerson::sharedInstance();

    //Line 2. Set the parameters for the camera. Such as which model the camera will target, and the offset positions
    cameraFirstPerson->setParameters(player,0.0,0.4,-0.5);

    //Line 3. set the camera behavior
    camera->setCameraBehavior(cameraFirstPerson);
    

}

void Earth::update(double dt){
    
    
}

void Earth::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(30.0f, director->getAspect(), 0.01f, 100.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-30.0f, 30.0f, -30.0f, 30.0f, -30.0f, 30.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPosition(0.0,2.0,-30.0);
    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(10.0,10.0,-10.0);
    U4DEngine::U4DVector3n diffuse(0.5,0.5,0.5);
    U4DEngine::U4DVector3n specular(0.1,0.1,0.1);
    light->setDiffuseColor(diffuse);
    light->setSpecularColor(specular);
    
    addChild(light);
    
    //Set the view direction of the camera and light
    //camera->viewInDirection(origin);
    
    light->viewInDirection(origin);
    
    //set the poly count to 5000. Default is 3000
    director->setPolycount(5000);
    
}

Earth::~Earth(){
    
    
}




