//
//  DemoWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "DemoWorld.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DDirectionalLight.h"
#include "U4DResourceLoader.h"
#include "SandboxLogic.h"

#include "U4DSlider.h"
#include "U4DWindow.h"
#include "U4DJoystick.h"
#include "U4DSkybox.h"
#include "U4DLayerManager.h"
#include "U4DLayer.h"
#include "U4DCallback.h"
#include "U4DDebugger.h"
#include "U4DBoundingAABB.h"
#include "U4DProfilerManager.h"
#include "U4DImage.h"
#include "U4DText.h"
#include "U4DRenderManager.h"
#include "U4DModelPipeline.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DPointLight.h"
#include "U4DShaderEntityPipeline.h"
#include "Enemy.h"
#include "U4DCameraFirstPerson.h"
#include "U4DCameraThirdPerson.h"
#include "U4DCameraInterface.h"

using namespace U4DEngine;

DemoWorld::DemoWorld():navigationShader(nullptr){
    
}

DemoWorld::~DemoWorld(){
    
}

void DemoWorld::init(){
    
    /*----DO NOT REMOVE. THIS IS REQUIRED-----*/
    //Configures the perspective view, shadows, lights and camera.
    setupConfiguration();
    /*----END DO NOT REMOVE.-----*/
    
    //The following code snippets loads scene data, renders the characters and skybox.
    
    
    /*---LOAD SCENE ASSETS HERE--*/
    //Load binary file with scene data
    U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();
    
    //The gamecene.u4d file contains the data for the scene (models)
    //All of the .u4d files are found in the Resource folder. Note, you will need to use the Digital Asset Converter tool to convert all game asset data into .u4d files. For more info, go to www.untoldengine.com.
    resourceLoader->loadSceneData("gamescene.u4d");

    //Load binary file with texture data for the game
    resourceLoader->loadTextureData("gametextures.u4d");
    
    //load ui textures contains images that can be used for the UIs. This contains buttons and joystick textures
    resourceLoader->loadTextureData("uiTextures.u4d");
    
    //load particle data that will be used when the player shoots
    resourceLoader->loadParticleData("redBulletEmitter.u4d");
    
    //load lights information (point and directional lights)
    resourceLoader->loadLightData("gamelights.u4d");
    
    //Load binary file with animation data
    resourceLoader->loadAnimationData("patrol.u4d");
    
    resourceLoader->loadAnimationData("idle.u4d");
    
    resourceLoader->loadAnimationData("shooting.u4d");
    
    resourceLoader->loadAnimationData("dead.u4d");
    
    //load font data. In this example, the font is used for the UIs.
    resourceLoader->loadFontData("uiFont.u4d");
    
    //setEnableGrid(true);
    
    //This is how you can create a new pipeline along with the corresponding shader in the engine.
    //create a new pipeline
    U4DEngine::U4DModelPipeline *nonvisiblePipeline=new U4DEngine::U4DModelPipeline("nonvisible");

    //Set the shaders used by the pipeline
    nonvisiblePipeline->initPipeline("vertexNonVisibleShader", "fragmentNonVisibleShader");
    
    
    /*
     THIS IS A TEMPLATE ON HOW MODELS ARE LOADED INTO THE ENGINE. KEEP IT AS A REFERENCE AS YOU REVIEW THE CODE BELOW:
     
     //create an U4DGameObject that represents the soldier
     U4DEngine::U4DGameObject *soldier=new U4DEngine::U4DGameObject();

     //Load up the model information into the engine. Note, the "hero" name comes from the scene made in Blender 3D
     if (soldier->loadModel("hero")) {

         //load the rendering information into the gpu
         soldier->loadRenderingInformation();

         //add the model to the scenegraph
         addChild(soldier);
     }
     
     */
    
    //This is a nice way to load all 46 models that make up the scene.
    U4DEngine::U4DGameObject *models[46];

        for(int i=0;i<sizeof(models)/sizeof(models[0]);i++){

            std::string name="model";
            name+=std::to_string(i);
            
            //create a U4DGame Object
            models[i]=new U4DEngine::U4DGameObject();

            //load all the model information into the object
            if (models[i]->loadModel(name.c_str())) {

                //If you want to disable shadows, then you can remove the shadow shader
                //models[i]->renderEntity->removePassPipelinePair(U4DEngine::shadowPass);

                //send all the information to the GPU
                models[i]->loadRenderingInformation();

                //add the model to the scenegraph
                addChild(models[i]);

            }
        }
    
    //Create a Hero object. Note, the hero object is a subclass of Player class
    hero=new Hero();
    
    //initialize the model with all the model information. Please see the Player class init method
    if (hero->init("hero")) {
        
        //add the hero to the scenegraph
        addChild(hero);
   
    }
    

    //Load up the german soldier models
    for(int i=0;i<sizeof(germanSoldier)/sizeof(germanSoldier[0]);i++){

        std::string name="germansoldier";
        name+=std::to_string(i);

        //create an Enemy Object. Note, the enemy object is a subclass of the Player class
        germanSoldier[i]=new Enemy();

        if (germanSoldier[i]->init(name.c_str())) {

            germanSoldier[i]->setHero(hero);
            
            //add the model to the scenegraph
            addChild(germanSoldier[i]);
            
        }
    }
    
    //Create an object that will represent the map of the scene. This will be used for collision detection with walls by using raycasts
    U4DEngine::U4DGameObject *mapLevel=new U4DEngine::U4DGameObject();

    //load the model information
    if(mapLevel->loadModel("map")){

        //since we don't want to render the map, we just want to use the geometric information, we set the pipeline declared previously. The shader will make the object invisible.
        mapLevel->setPipeline("nonvisible");

        //enable the mesh manager for raycasting collision detection
        mapLevel->enableMeshManager(2);

        //load the rendering information to the GPU
        mapLevel->loadRenderingInformation();

        //add the model to the scenegraph
        addChild(mapLevel);

    }

    hero->setMap(mapLevel);
    
    //create layer manager. Not necessary, but I will create a layer and add HUD components to the layer
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

    //set this view (U4DWorld subclass) to the layer Manager
    layerManager->setWorld(this);

    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    //create the Layer
    U4DEngine::U4DLayer* HUDLayer=new U4DEngine::U4DLayer("HUDLayer");

    //create a new pipeline for the Navigation Hud
    U4DShaderEntityPipeline* navigationPipeline=new U4DShaderEntityPipeline("navigationpipeline");
    
    //set the shader's pipeline
    navigationPipeline->initPipeline("vertexNavShader","fragmentNavShader");
    
    //create a new pipeline for the minimap hud
    U4DShaderEntityPipeline *minimapPipeline=new U4DShaderEntityPipeline("minimappipeline");
    
    //set the shader's pipeline
    minimapPipeline->initPipeline("vertexMinimapShader","fragmentMinimapShader");
    
    //create the navigation shader entity. We initialize the size to 1 since we are just going to send one set of data
    navigationShader=new U4DEngine::U4DShaderEntity(1);
    
    //link the pipeline to the entity
    navigationShader->setPipeline("navigationpipeline");
    
    //set the shader entity dimensions
    navigationShader->setShaderDimension(director->getDisplayWidth()/2.0, director->getDisplayHeight()/2.0);
    
    //set the shader entity position on the screen
    navigationShader->translateTo(0.0, 0.5, 0.0);
    
    //send the shader entity rendering information to the gpu
    navigationShader->loadRenderingInformation();
    
    //create the minimap shader entity. We initialize with a size of four since we are going to be sending 4 sets of data to the shader entity
    minimapShader=new U4DEngine::U4DShaderEntity(4);
    
    //link the pipeline to the entity
    minimapShader->setPipeline("minimappipeline");
    
    //set the shader entity dimensions
    minimapShader->setShaderDimension(director->getDisplayWidth()/5.0, director->getDisplayHeight()/5.0);
    
    //set the texture for the shader entity
    minimapShader->setTexture0("minimap.png");
    
    //set the shader entity position on the screen
    minimapShader->translateTo(-0.7, -0.7, 0.0);
    
    //send the shader entity rendering information to the gpu
    minimapShader->loadRenderingInformation();
    
    //add both shader entities to the HUDLayer's scenegraph
    HUDLayer->addChild(navigationShader,-10);
    
    HUDLayer->addChild(minimapShader,-10);
    
    //add the HUD layer to the layer manager
    layerManager->addLayerToContainer(HUDLayer);

    //push layer to the front of the rendering sequence
    layerManager->pushLayer("HUDLayer");

    //Render a skybox
    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();

    //initialize the skybox
    skybox->initSkyBox(60.0,"LeftImage.png","RightImage.png","TopImage.png","BottomImage.png","FrontImage.png", "BackImage.png");

    //add the skybox to the scenegraph with appropriate z-depth
    addChild(skybox);
    
    //Set the camera perspective view. either first-person or third person.
    
//    //Instantiate the camera
//    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
//
//    //Line 1. Instantiate the camera interface and the type of camera you desire
//    U4DEngine::U4DCameraInterface *cameraFirstPerson=U4DEngine::U4DCameraFirstPerson::sharedInstance();
//
//    //Line 2. Set the parameters for the camera. Such as which model the camera will target, and the offset positions
//    cameraFirstPerson->setParameters(hero,0.0,0.3,0.35);
//
//    //Line 3. set the camera behavior
//    camera->setCameraBehavior(cameraFirstPerson);
    
    //Instantiate the camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    //Line 1. Instantiate the camera interface and the type of camera you desire
    U4DEngine::U4DCameraInterface *cameraThirdPerson=U4DEngine::U4DCameraThirdPerson::sharedInstance();

    //Line 2. Set the parameters for the camera. Such as which model the camera will target, and the offset positions
    cameraThirdPerson->setParameters(hero,0.0,5.0,10.0);

    //Line 3. set the camera behavior
    camera->setCameraBehavior(cameraThirdPerson);
    
    //Enable the debugger. This will allow you to check the profiler and FPS
    U4DEngine::U4DDebugger *debugger=U4DEngine::U4DDebugger::sharedInstance();
    debugger->setEnableDebugger(true,this);

}


void DemoWorld::update(double dt){
    
    //here we are going to update the orientation and position information necessary by the Navigation and Minimap entities.
    //essentially, these entities require the position and orientation of the models.

    if (navigationShader!=nullptr) {

        //comput the yaw of the hero soldier
        U4DEngine::U4DVector3n v0=hero->getEntityForwardVector();
        U4DEngine::U4DMatrix3n m=hero->getAbsoluteMatrixOrientation();
        U4DEngine::U4DVector2n heroPosition(hero->getAbsolutePosition().x,hero->getAbsolutePosition().z);
        U4DEngine::U4DVector3n xDir(1.0,0.0,0.0);
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);

        U4DEngine::U4DVector3n v1=m*v0;

        float yaw=v0.angle(v1);

        v1.normalize();

        if (xDir.dot(v1)>U4DEngine::zeroEpsilon) {

            yaw=360.0-yaw;
        }

        //send the yaw information to the navigation shader
        U4DVector4n param(yaw,0.0,0.0,0.0);

        navigationShader->updateShaderParameterContainer(0, param);

        //Divide by 40 since this is half the width and height of the minimap texture
        heroPosition.x/=40.0;
        heroPosition.y/=40.0;

        //send the hero's position to the minimap shader
        U4DVector4n paramPosition(heroPosition.x,heroPosition.y,yaw,0.0);
        minimapShader->updateShaderParameterContainer(0, paramPosition);

        //get position for enemies

        for(int i=0;i<sizeof(germanSoldier)/sizeof(germanSoldier[0]);i++){

            U4DEngine::U4DVector2n enemyPosition(germanSoldier[i]->getAbsolutePosition().x,germanSoldier[i]->getAbsolutePosition().z);
            enemyPosition/=40.0;

            //send the enemies' position to the minimap shader
            U4DVector4n paramPosition(enemyPosition.x,enemyPosition.y,0.0,0.0);
            minimapShader->updateShaderParameterContainer(i+1, paramPosition);

        }

    }
}

//Sets the configuration for the engine: Perspective view, shadows, light
void DemoWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.001f, 400.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-60.0f, 60.0f, -60.0f, 60.0f, -60.0f, 60.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    U4DEngine::U4DVector3n cameraPosition(0.0,10.0,-35.0);

    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DDirectionalLight *light=U4DDirectionalLight::sharedInstance();
    light->translateTo(10.0,30.0,-30.0);
    U4DEngine::U4DVector3n diffuse(1.0,1.0,1.0);
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
