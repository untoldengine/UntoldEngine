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

using namespace U4DEngine;

void Earth::init(){
    
    /*----DO NOT REMOVE. THIS IS REQUIRED-----*/
    //Configures the perspective view, shadows, lights and camera.
    setupConfiguration();
    
    //Renders the background models: skybox and island models. Remove if you want to.
    setupBackgroundModels();
    
    ////////////CREATE ASTRONAUT HERE/////////////
    
    
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
    U4DEngine::U4DVector3n cameraPosition(0.0,5.0,-10.0);
    
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
    camera->viewInDirection(origin);
    
    light->viewInDirection(origin);
    
    //set the poly count to 5000. Default is 3000
    director->setPolycount(5000);
    
}

void Earth::setupBackgroundModels(){
    
    //create island and skybox
    
    //Create an instance of U4DGameObject type
    U4DGameObject *island=new U4DGameObject();
    
    //Load attribute (rendering information) into the game entity
    if (island->loadModel("island","astronautAttributes.u4d")) {
        
        island->setEnableShadow(true);
        
        //Load rendering information into the GPU
        island->loadRenderingInformation();
        
        //Add walkway to scenegraph
        addChild(island);
        
    }
    
    if (island!=nullptr) {
        
        //enable kinetics
        island->enableKineticsBehavior();
        
        //enable collision
        island->enableCollisionBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        island->setGravity(zero);
        
        //set Coefficient of Restitution
        island->initCoefficientOfRestitution(0.9);
        
        //set mass
        island->initMass(100.0);
        
    }
    
    //add a skybox here
    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();
    
    skybox->initSkyBox(20.0,"LeftImage.png","RightImage.png","TopImage.png","BottomImage.png","FrontImage.png", "BackImage.png");
    
    addChild(skybox,-1);
    
}

Earth::~Earth(){
    
    
}




