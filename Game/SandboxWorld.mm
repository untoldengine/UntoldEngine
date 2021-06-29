//
//  SandboxWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "SandboxWorld.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DDirectionalLight.h"

#include "U4DDebugger.h"
#include "U4DSkybox.h"
#include "U4DModelPipeline.h"
#include "U4DDynamicAction.h"

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
    
    
    setEnableGrid(true);
    
    U4DEngine::U4DModelPipeline *testPipeline=new U4DEngine::U4DModelPipeline("testPipeline");
        
    testPipeline->initPipeline("vertexTestPipelineShader", "fragmentTestPipelineShader");

    
//    //Create an instance of U4DGameObject type
//    myAstronaut=new U4DEngine::U4DModel();
//
//    //Load attribute (rendering information) into the game entity
//    if (myAstronaut->loadModel("astronaut")) {
//
//        U4DEngine::U4DDynamicAction *kineticAction=new U4DDynamicAction(myAstronaut);
//
//        kineticAction->enableKineticsBehavior();
//
//        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//
//        kineticAction->setGravity(zero);
//
//        kineticAction->enableCollisionBehavior();
//
//        //Line 4. Load rendering information into the GPU
//        myAstronaut->loadRenderingInformation();
//
//        //Line 5. Add astronaut to the scenegraph
//        addChild(myAstronaut);
//
//    }
//
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
//
    //Create an instance of U4DGameObject type
    U4DEngine::U4DModel *ground=new U4DEngine::U4DModel();

    //Line 3. Load attribute (rendering information) into the game entity
    if (ground->loadModel("field")) {

        ground->setPipeline("testPipeline");
        
        U4DEngine::U4DDynamicAction *gkinetic=new U4DDynamicAction(ground);

        //gkinetic->enableKineticsBehavior();

        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

        gkinetic->setGravity(zero);

        gkinetic->enableCollisionBehavior();

        //Line 4. Load rendering information into the GPU
        ground->loadRenderingInformation();

        //Line 5. Add astronaut to the scenegraph
        addChild(ground);

    }
//
//    //Render a skybox
//    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();
//
//    //initialize the skybox
//    skybox->initSkyBox(60.0,"LeftImage.png","RightImage.png","TopImage.png","BottomImage.png","FrontImage.png", "BackImage.png");
//
//    //add the skybox to the scenegraph with appropriate z-depth
//    addChild(skybox);

    U4DEngine::U4DDebugger *debugger=U4DEngine::U4DDebugger::sharedInstance();
    debugger->setEnableDebugger(true,this);
    
}


void SandboxWorld::update(double dt){
    
    
}

//Sets the configuration for the engine: Perspective view, shadows, light
void SandboxWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(65.0f, director->getAspect(), 0.001f, 400.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-30.0f, 30.0f, -30.0f, 30.0f, -30.0f, 30.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    U4DEngine::U4DVector3n cameraPosition(0.0,5.0,-17.0);

    
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
