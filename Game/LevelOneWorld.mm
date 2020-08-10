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
#include "U4DCameraBasicFollow.h"
#include "LevelOneUILayer.h"
#include "Ball.h"
#include "FieldAnalyzer.h"
#include "PathAnalyzer.h"
#include "TeamSettings.h"

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
    resourceLoader->loadSceneData("soccergame.u4d");

    //Load binary file with texture data
    resourceLoader->loadTextureData("soccerTextures.u4d");
    
    //Animation for astronaut
    //load binary file with animation data
    resourceLoader->loadAnimationData("runningAnimation.u4d");

    resourceLoader->loadAnimationData("idleAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightdribbleAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightsolehaltAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightpassAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightshotAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightstandtackleAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightforwardcontainAnimation.u4d");
    
    //RENDER THE MODELS
    
    //render the ground
    ground=new U4DEngine::U4DGameObject();

    if(ground->loadModel("field")){

        ground->setShader("vertexFieldShader", "fragmentFieldShader");
        
        
        //set shadows
        ground->setEnableShadow(true);
        
        ground->setNormalMapTexture("FieldNormalMap.png");
        
        //send info to gpu
        ground->loadRenderingInformation();

        //add to scenegraph
        addChild(ground);
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

    U4DEngine::U4DGameObject *fieldGoals[2];

    for(int i=0;i<sizeof(fieldGoals)/sizeof(fieldGoals[0]);i++){

        std::string name="fieldgoal";

        name+=std::to_string(i);

        fieldGoals[i]=new U4DEngine::U4DGameObject();

        if(fieldGoals[i]->loadModel(name.c_str())){

            fieldGoals[i]->setEnableShadow(true);

            fieldGoals[i]->loadRenderingInformation();

            addChild(fieldGoals[i]);
        }

    }
    
    //render the ball
    Ball *ball=Ball::sharedInstance();
    
    if (ball->init("ball")) {
        
        addChild(ball);
        
    }
    
    //Initialize both teams
    teamA=new Team();
    teamB=new Team();
    
    teamA->setOppositeTeam(teamB);
    teamB->setOppositeTeam(teamA);

    TeamSettings *teamSettings=TeamSettings::sharedInstance();
    std::vector<U4DEngine::U4DVector4n> teamAKit=teamSettings->getTeamAKit();
    
    //create the player object and render it
    
    Player *players[3];
    
    for(int i=0;i<sizeof(players)/sizeof(players[0]);i++){
        
        std::string name="player";
        name+=std::to_string(i);
        
        players[i]=new Player();
        
        if(players[i]->init(name.c_str())){
        
            //load the team kit
            for(int j=0;j<teamAKit.size();j++){
                
                players[i]->updateShaderParameterContainer(j,teamAKit.at(j));
                
            }
            
            addChild(players[i]);
            
            players[i]->changeState(idle);
            
            players[i]->addToTeam(teamA);
            
            teamA->addPlayer(players[i]);
        
        }

    }
    
    
    
    
    Player *oppositePlayers[3];
    
    for(int i=0;i<sizeof(oppositePlayers)/sizeof(oppositePlayers[0]);i++){
        
        std::string name="oppositeplayer";
        name+=std::to_string(i);
        
        oppositePlayers[i]=new Player();
        
        if(oppositePlayers[i]->init(name.c_str())){
            
            addChild(oppositePlayers[i]); 
            
            oppositePlayers[i]->changeState(idle);
            
            oppositePlayers[i]->addToTeam(teamB);
            
            teamB->addPlayer(oppositePlayers[i]);
        }
    }
    
    players[0]->changeState(pursuit);
    
    teamA->startAnalyzing();
    
    
    //Visualizers
    
    playerVisualizerShader=new U4DEngine::U4DShaderEntity(22);

    playerVisualizerShader->setShader("vertexRadarShader","fragmentRadarShader");

    playerVisualizerShader->setTexture0("radarfield.png");

    playerVisualizerShader->setShaderDimension(200.0, 113.0);

    playerVisualizerShader->translateTo(0.0, -0.7, 0.0);

    playerVisualizerShader->loadRenderingInformation();

    addChild(playerVisualizerShader,-10);
    
    //Uncomment this section to view the visualizers
//    //Create influence map shader
//    influenceMapShader=new U4DEngine::U4DShaderEntity(441);
//
//    influenceMapShader->setShader("vertexInfluenceShader", "fragmentInfluenceShader");
//
//    influenceMapShader->setTexture0("radarField.png");
//
//    influenceMapShader->setShaderDimension(200.0, 113.0);
//
//    influenceMapShader->translateTo(0.7, -0.7, 0.0);
//
//    influenceMapShader->loadRenderingInformation();
//
//    addChild(influenceMapShader,-10);
//
//
//    //Create Navigation map shader
//    navigationMapShader=new U4DEngine::U4DShaderEntity(30);
//
//    navigationMapShader->setShader("vertexNavigationShader", "fragmentNavigationShader");
//
//    navigationMapShader->setTexture0("radarField.png");
//
//    navigationMapShader->setShaderDimension(200.0, 113.0);
//
//    navigationMapShader->translateTo(-0.7, -0.7, 0.0);
//
//    navigationMapShader->loadRenderingInformation();
//
//    addChild(navigationMapShader,-10);
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    if (director->getDeviceOSType()==U4DEngine::deviceOSIOS) {

        //Create Mobile Layer with buttons & joystic
        U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

        //set the world (view component) for the layer manager --MAY WANT TO FIX THIS. DONT LIKE SETTING THE VIEW HERE FOR THE LAYER MANAGER
        layerManager->setWorld(this);

        //create the Mobile Layer
        LevelOneUILayer *levelOneUILayer=new LevelOneUILayer("levelOneUILayer");

        levelOneUILayer->init();

        layerManager->addLayerToContainer(levelOneUILayer);

        layerManager->pushLayer("levelOneUILayer");
    }
    
    //Instantiate the camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    //Instantiate the camera interface and the type of camera you desire
    U4DEngine::U4DCameraInterface *cameraBasicFollow=U4DEngine::U4DCameraBasicFollow::sharedInstance();

    //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
    cameraBasicFollow->setParameters(ball,0.0,25.0,-40.0);

    //set the camera behavior
    camera->setCameraBehavior(cameraBasicFollow);
    
}

void LevelOneWorld::update(double dt){
    
    //get the ball position
    Ball *ball=Ball::sharedInstance();

    U4DEngine::U4DVector2n ballPosition(ball->getAbsolutePosition().x,ball->getAbsolutePosition().z);

    ballPosition.x/=80.0;
    ballPosition.y/=45.0;

    U4DVector4n param0(ballPosition.x,ballPosition.y,0.0,0.0);
    playerVisualizerShader->updateShaderParameterContainer(0, param0);

    //index used for the shader entity container
    int index=1;

    for(const auto &n:teamA->getPlayers()){

        U4DEngine::U4DVector2n playerPos(n->getAbsolutePosition().x,n->getAbsolutePosition().z);

        playerPos.x/=80.0;
        playerPos.y/=45.0;

        U4DVector4n param(playerPos.x,playerPos.y,0.0,0.0);
        playerVisualizerShader->updateShaderParameterContainer(index, param);

        index++;
    }

      //Uncomment this section to view the visualizers
//    FieldAnalyzer *fieldAnalyzer=FieldAnalyzer::sharedInstance();
//
//    for(int i=0;i<fieldAnalyzer->getCellContainer().size();i++){
//
//        Cell cell=fieldAnalyzer->getCellContainer().at(i);
//
//        U4DVector4n cellProperty(cell.x,cell.y,cell.influence,cell.isTeam);
//
//        influenceMapShader->updateShaderParameterContainer(i, cellProperty);
//
//    }
//
//    PathAnalyzer *pathAnalyzer=PathAnalyzer::sharedInstance();
//
//    //send size of path
//    U4DEngine::U4DVector4n navParam0(pathAnalyzer->getNavigationPath().size(),0.0,0.0,0.0);
//    navigationMapShader->updateShaderParameterContainer(0, navParam0);
//
//    int p=1;
//
//    //This print the computed path, but the path does not contain the target position
//    for(auto &n:pathAnalyzer->getNavigationPath()){
//
//        U4DEngine::U4DVector4n navParam(n.pointA.x/80.0,n.pointA.z/45.0,n.pointB.x/80.0,n.pointB.z/45.0);
//        navigationMapShader->updateShaderParameterContainer(p, navParam);
//
//        p++;
//
//    }
    
}

void LevelOneWorld::setupConfiguration(){
    
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
    U4DEngine::U4DVector3n cameraPosition(0.0,16.0,-25.0);
    
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

LevelOneWorld::~LevelOneWorld(){
    
    delete ground;
    
}




