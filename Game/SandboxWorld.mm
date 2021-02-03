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
#include "U4DPointLight.h"

using namespace U4DEngine;

SandboxWorld::SandboxWorld(){
    
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
    
    //The spaceScene.u4d file contains the data for the astronaut model and ground
    //All of the .u4d files are found in the Resource folder. Note, you will need to use the Digital Asset Converter tool to convert all game asset data into .u4d files. For more info, go to www.untoldengine.com.
    resourceLoader->loadSceneData("flyinghud.u4d");

    //Load binary file with texture data for the astronaut
    resourceLoader->loadTextureData("flyinghudTextures.u4d");
    
    //load ui textures contains images that can be used for the UIs. Look at the joystick instance below.
    resourceLoader->loadTextureData("uiTextures.u4d");
    
    //load particle data
    resourceLoader->loadParticleData("redBulletEmitter.u4d");
    
    //Load binary file with animation data
    resourceLoader->loadAnimationData("astronautWalkAnim.u4d");
    
    //load font data. In this example, the font is used for the UIs.
    resourceLoader->loadFontData("uiFont.u4d");
    
    setEnableGrid(true);
    
    U4DEngine::U4DGameObject *houses[40];

    for(int i=0;i<sizeof(houses)/sizeof(houses[0]);i++){

        std::string name="house";
        name+=std::to_string(i);

        houses[i]=new U4DEngine::U4DGameObject();

        if (houses[i]->loadModel(name.c_str())) {


            houses[i]->loadRenderingInformation();

            addChild(houses[i]);

        }
    }

        //Create an instance of U4DGameObject type
        U4DEngine::U4DGameObject *ground=new U4DEngine::U4DGameObject();

        //Line 3. Load attribute (rendering information) into the game entity
        if (ground->loadModel("ground")) {

//            ground->enableKineticsBehavior();
//
//            U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//
//            ground->setGravity(zero);
//
//            ground->enableCollisionBehavior();

            //Line 4. Load rendering information into the GPU
            ground->loadRenderingInformation();

            //Line 5. Add astronaut to the scenegraph
            addChild(ground);

        }

    //Create an instance of U4DGameObject type
    U4DEngine::U4DGameObject *paperplane=new U4DEngine::U4DGameObject();

    //Line 3. Load attribute (rendering information) into the game entity
    if (paperplane->loadModel("paperplane")) {

//            ground->enableKineticsBehavior();
//
//            U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//
//            ground->setGravity(zero);
//
//            ground->enableCollisionBehavior();

        //Line 4. Load rendering information into the GPU
        paperplane->loadRenderingInformation();

        //Line 5. Add astronaut to the scenegraph
        addChild(paperplane);

    }
    
    //Create an instance of U4DGameObject type
//    myAstronaut=new U4DEngine::U4DGameObject();
//
//    //Load attribute (rendering information) into the game entity
//    if (myAstronaut->loadModel("astronaut")) {
//
//        myAstronaut->enableKineticsBehavior();
//
//        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//
//        myAstronaut->setGravity(zero);
//
//        myAstronaut->enableCollisionBehavior();
//
//        //Line 4. Load rendering information into the GPU
//        myAstronaut->loadRenderingInformation();
//
//        //Line 5. Add astronaut to the scenegraph
//        addChild(myAstronaut);
//
//    }
  
//    //Line 2. Create an Animation object and link it to the 3D model
//    U4DEngine::U4DAnimation *walkAnimation=new U4DEngine::U4DAnimation(myAstronaut);
//
//    //Line 3. Load animation data into the animation object
//    if(myAstronaut->loadAnimationToModel(walkAnimation, "walking")){
//
//        //If animation data was successfully loaded, you can set other parameters here. For now, we won't do this.
//
//    }
//
//    //Line 4. Check if the animation object exist and play the animation
//    if (walkAnimation!=nullptr) {
//
//        walkAnimation->play();
//
//    }
    
    //Create an instance of U4DGameObject type
//    U4DEngine::U4DGameObject *ground=new U4DEngine::U4DGameObject();
//
//    //Line 3. Load attribute (rendering information) into the game entity
//    if (ground->loadModel("island")) {
//
//        ground->enableKineticsBehavior();
//
//        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//
//        ground->setGravity(zero);
//
//        ground->enableCollisionBehavior();
//
//        //Line 4. Load rendering information into the GPU
//        ground->loadRenderingInformation();
//
//        //Line 5. Add astronaut to the scenegraph
//        addChild(ground);
//
//    }
    
    //Render a skybox
    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();

    //initialize the skybox
    skybox->initSkyBox(60.0,"LeftImage.png","RightImage.png","TopImage.png","BottomImage.png","FrontImage.png", "BackImage.png");

    //add the skybox to the scenegraph with appropriate z-depth
    addChild(skybox);
//
    //Need to load the lights from blender, this is not efficient.
    U4DEngine::U4DPointLight *pointLights=U4DEngine::U4DPointLight::sharedInstance();


        U4DEngine::U4DVector3n light0(0.0,1.0,0.0);
        U4DEngine::U4DVector3n light1(0.0,2.0,-10.0);
        U4DEngine::U4DVector3n light2(0.0,1.0,-20.0);
        U4DEngine::U4DVector3n light3(0.0,2.0,10.0);

        U4DEngine::U4DVector3n light4(-12.0,1.0,0.0);
        U4DEngine::U4DVector3n light5(12.0,2.0,-10.0);
        U4DEngine::U4DVector3n light6(-12.0,1.0,-20.0);
        U4DEngine::U4DVector3n light7(12.0,2.0,10.0);

        U4DEngine::U4DVector3n light8(12.0,1.0,0.0);
        U4DEngine::U4DVector3n light9(-12.0,2.0,-10.0);
        U4DEngine::U4DVector3n light10(12.0,1.0,-20.0);
        U4DEngine::U4DVector3n light11(-12.0,2.0,10.0);

        U4DEngine::U4DVector3n light12(0.0,1.0,-35.0);
        U4DEngine::U4DVector3n light13(-12.0,2.0,-35.0);
        U4DEngine::U4DVector3n light14(12.0,1.0,-35.0);
        U4DEngine::U4DVector3n light15(-24.0,2.0,-35.0);

        U4DEngine::U4DVector3n diffuseColor0(1.0,0.0,0.0);
        U4DEngine::U4DVector3n diffuseColor1(0.0,0.0,1.0);
        U4DEngine::U4DVector3n diffuseColor2(1.0,0.0,1.0);
        U4DEngine::U4DVector3n diffuseColor3(0.0,1.0,1.0);

        pointLights->addLight(light0, diffuseColor0,1.0,0.4,0.004);
        pointLights->addLight(light1, diffuseColor1,1.0,0.4,0.004);
        pointLights->addLight(light2, diffuseColor2,2.0,0.4,0.004);
        pointLights->addLight(light3, diffuseColor3,1.0,0.4,0.004);

        pointLights->addLight(light4, diffuseColor0,1.0,0.4,0.004);
        pointLights->addLight(light5, diffuseColor1,1.0,0.4,0.004);
        pointLights->addLight(light6, diffuseColor2,2.0,0.4,0.004);
        pointLights->addLight(light7, diffuseColor3,1.0,0.4,0.004);

        pointLights->addLight(light8, diffuseColor0,1.0,0.4,0.004);
        pointLights->addLight(light9, diffuseColor1,1.0,0.4,0.004);
        pointLights->addLight(light10, diffuseColor2,2.0,0.4,0.004);
        pointLights->addLight(light11, diffuseColor3,1.0,0.4,0.004);

        pointLights->addLight(light12, diffuseColor0,1.0,0.4,0.004);
        pointLights->addLight(light13, diffuseColor1,1.0,0.4,0.004);
        pointLights->addLight(light14, diffuseColor2,2.0,0.4,0.004);
        pointLights->addLight(light15, diffuseColor3,1.0,0.4,0.004);

    U4DEngine::U4DDebugger *debugger=U4DEngine::U4DDebugger::sharedInstance();
    debugger->setEnableDebugger(true,this);
    
}


void SandboxWorld::update(double dt){
    
    //rotateBy(0.0,0.1,0.0);
    
}

//Sets the configuration for the engine: Perspective view, shadows, light
void SandboxWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.001f, 400.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-30.0f, 30.0f, -30.0f, 30.0f, -30.0f, 30.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
<<<<<<< HEAD
    U4DEngine::U4DVector3n cameraPosition(0.0,10.0,-20.0);
=======
    U4DEngine::U4DVector3n cameraPosition(0.0,3.0,-50.0);
>>>>>>> issue-263
    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DDirectionalLight *light=U4DDirectionalLight::sharedInstance();
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
