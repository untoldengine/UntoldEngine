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
#include "U4DDirectionalLight.h"
#include "U4DResourceLoader.h"
#include "UserCommonProtocols.h"
#include "U4DCameraInterface.h"
#include "U4DCameraBasicFollow.h"
#include "U4DCameraThirdPerson.h"
#include "U4DLayerManager.h"
#include "Player.h"
#include "Ball.h"
#include "Team.h"
#include "LevelOneLogic.h"
#include "PlayerStateChase.h"
#include "PlayerStateGroupNav.h"
#include "PlayerStateIdle.h"
#include "PlayerStateIntercept.h"
#include "PlayerStateMark.h"
#include "PlayerStateHalt.h"
#include "FieldAnalyzer.h"
#include "PathAnalyzer.h"
#include "U4DModelPipeline.h"
#include "U4DShaderEntityPipeline.h"
#include "U4DDebugger.h"
#include "U4DJoystick.h"

#include "U4DLayerManager.h"
#include "U4DLayer.h"
#include "FormationManager.h"

#include "U4DBoundingAABB.h"

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
    
    //load ui textures contains images that can be used for the UIs. Look at the joystick instance below.
    resourceLoader->loadTextureData("uiTextures.u4d");
    
    //load font data. In this example, the font is used for the UIs.
    resourceLoader->loadFontData("uiFont.u4d");
    
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

    resourceLoader->loadAnimationData("righttapAnimation.u4d");
    
    resourceLoader->loadAnimationData("joggingAnimation.u4d");
    
    resourceLoader->loadAnimationData("slidingtackleAnimation.u4d");

    U4DEngine::U4DModelPipeline *fieldPipeline=new U4DEngine::U4DModelPipeline("fieldpipeline"); 
        
    fieldPipeline->initPipeline("vertexFieldShader", "fragmentFieldShader");

    U4DEngine::U4DShaderEntityPipeline *radarShader=new U4DEngine::U4DShaderEntityPipeline("radar");
        
    radarShader->initPipeline("vertexRadarShader","fragmentRadarShader");
    
    U4DEngine::U4DModelPipeline *nonvisiblePipeline=new U4DEngine::U4DModelPipeline("nonvisible");
        
    nonvisiblePipeline->initPipeline("vertexNonVisibleShader", "fragmentNonVisibleShader");

    U4DEngine::U4DShaderEntityPipeline *playerIndicatorPipeline=new U4DEngine::U4DShaderEntityPipeline("playerindicator");
        
    playerIndicatorPipeline->initPipeline("vertexInstructionsShader", "fragmentInstructionsShader");
    
    U4DEngine::U4DShaderEntityPipeline *influenceMapPipeline=new U4DEngine::U4DShaderEntityPipeline("influencemap");
        
    influenceMapPipeline->initPipeline("vertexInfluenceShader", "fragmentInfluenceShader");
    
    
    
    
    //RENDER THE MODELS
    U4DEngine::U4DJoystick *joystick=new U4DEngine::U4DJoystick("joystick",0.0,-0.5,150.0,150.0);

//    //Get director object
//    U4DDirector *director=U4DDirector::sharedInstance();
    
    //render the ground
    ground=new U4DEngine::U4DGameObject();

    if(ground->loadModel("field")){

        //ground->setPipeline("fieldpipeline");
//
//        ground->setNormalMapTexture("FieldNormalMap.png");
        
        //send info to gpu
        ground->loadRenderingInformation();

        //add to scenegraph
        addChild(ground);
    }
    
    U4DEngine::U4DGameObject *fieldGoals[2];

    for(int i=0;i<sizeof(fieldGoals)/sizeof(fieldGoals[0]);i++){

        std::string name="fieldgoal";

        name+=std::to_string(i);

        fieldGoals[i]=new U4DEngine::U4DGameObject();

        if(fieldGoals[i]->loadModel(name.c_str())){

            
            fieldGoals[i]->loadRenderingInformation();

            addChild(fieldGoals[i]);
        }

    }
    
    U4DEngine::U4DGameObject *bleachers[3];

    for(int i=0;i<sizeof(bleachers)/sizeof(bleachers[0]);i++){

        std::string name="seating";

        name+=std::to_string(i);

        bleachers[i]=new U4DEngine::U4DGameObject();

        if(bleachers[i]->loadModel(name.c_str())){

            
            bleachers[i]->loadRenderingInformation();

            addChild(bleachers[i]);
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

    LevelOneLogic *levelOneLogic=dynamic_cast<LevelOneLogic*>(getGameModel());

    levelOneLogic->setControllingTeam(teamA);
    levelOneLogic->setMarkingTeam(teamB);
    
    for(int i=0;i<sizeof(players)/sizeof(players[0]);i++){

        std::string name="player";
        name+=std::to_string(i);

        players[i]=new Player();

        if(players[i]->init(name.c_str())){

            
            //I am of type
            players[i]->setCollisionFilterCategory(kPlayer);

            //I collide with type of bullet and player. The enemies can collide among themselves.
            players[i]->setCollisionFilterMask(kPlayer);

            //set a tag
            players[i]->setCollidingTag("player");

            addChild(players[i]);
            
            players[i]->rotateBy(0.0, 180.0, 0.0);
            teamA->addPlayer(players[i]);
            
            
            
        }

    }



    Player *oppositePlayers[5];

    for(int i=0;i<sizeof(oppositePlayers)/sizeof(oppositePlayers[0]);i++){

        std::string name="oppositeplayer";
        name+=std::to_string(i);

        oppositePlayers[i]=new Player();

        if(oppositePlayers[i]->init(name.c_str())){

            addChild(oppositePlayers[i]);

            teamB->addPlayer(oppositePlayers[i]);

            //set player index for team formation
            oppositePlayers[i]->setPlayerIndex(i);
        }

    }

    players[0]->changeState(PlayerStateChase::sharedInstance());


//    oppositePlayers[0]->setEnableStandTackle(true);
    //oppositePlayers[0]->changeState(PlayerStateMark::sharedInstance());

    //teamA->startAnalyzing();
    teamB->startAnalyzing();
    
    

    //Instantiate the camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    //Instantiate the camera interface and the type of camera you desire
    U4DEngine::U4DCameraInterface *cameraBasicFollow=U4DEngine::U4DCameraBasicFollow::sharedInstance();

    //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
    //cameraBasicFollow->setParameters(ball,0.0,7.0,-7.0);
    cameraBasicFollow->setParametersWithBoxTracking(ball,0.0,10.0,-15.0,U4DEngine::U4DPoint3n(-2.0,-2.0,-2.0),U4DEngine::U4DPoint3n(2.0,2.0,2.0));
    
    //set the camera behavior
    camera->setCameraBehavior(cameraBasicFollow);

    //Visualizers

//       playerVisualizerShader=new U4DEngine::U4DShaderEntity(9);
//
//       playerVisualizerShader->setPipeline("radar");
//
//       playerVisualizerShader->setTexture0("minimap.png");
//
//       playerVisualizerShader->setShaderDimension(200.0, 113.0);
//
//       playerVisualizerShader->translateTo(0.0, -0.7, 0.0);
//
//       playerVisualizerShader->loadRenderingInformation();
//
//       addChild(playerVisualizerShader,-10);

//        //Create influence map shader
//        influenceMapShader=new U4DEngine::U4DShaderEntity(441);
//
//        influenceMapShader->setPipeline("influencemap");
//
//        influenceMapShader->setTexture0("minimap.png");
//
//        influenceMapShader->setShaderDimension(200.0, 113.0);
//
//        influenceMapShader->translateTo(0.7, -0.7, 0.0);
//
//        influenceMapShader->loadRenderingInformation();
//
//        addChild(influenceMapShader,-10);

//        //Create Navigation map shader
//        navigationMapShader=new U4DEngine::U4DShaderEntity(30);
//
//        navigationMapShader->setShader("vertexNavigationShader", "fragmentNavigationShader");
//
//        navigationMapShader->setTexture0("minimap.png");
//
//        navigationMapShader->setShaderDimension(200.0, 113.0);
//
//        navigationMapShader->translateTo(-0.7, -0.7, 0.0);
//
//        navigationMapShader->loadRenderingInformation();
//
//        addChild(navigationMapShader,-10);

    //Create Player Indicator shader
//    playerIndicatorShader=new U4DEngine::U4DShaderEntity(1);
//
//    playerIndicatorShader->setPipeline("playerindicator");
//
//    playerIndicatorShader->setShaderDimension(director->getDisplayWidth(), director->getDisplayHeight());
//
//    playerIndicatorShader->loadRenderingInformation();
//
//    addChild(playerIndicatorShader,-10);
//
//    levelOneLogic->setPlayerIndicator(playerIndicatorShader);


    //Store initial pos
    ballInitPosition=ball->getAbsolutePosition();
    player0InitPosition=players[0]->getAbsolutePosition();
//    player1InitPosition=players[1]->getAbsolutePosition();
//    player2InitPosition=players[2]->getAbsolutePosition();

    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

    //set this view (U4DWorld subclass) to the layer Manager
    layerManager->setWorld(this);

    //create Layers
    U4DEngine::U4DLayer* mainMenuLayer=new U4DEngine::U4DLayer("menuLayer");

    //Create buttons to add to the layer
    //buttonA=new U4DEngine::U4DButton("buttonA",-0.6,0.0,103.0,20.0,"reset","uiFont");

    //create a callback for button A
//    U4DEngine::U4DCallback<LevelOneWorld>* buttonACallback=new U4DEngine::U4DCallback<LevelOneWorld>;
//
//    buttonACallback->scheduleClassWithMethod(this, &LevelOneWorld::actionOnButtonA);
//
//    buttonA->setCallbackAction(buttonACallback);

    //add the buttons to the layer
    mainMenuLayer->addChild(joystick);

    layerManager->addLayerToContainer(mainMenuLayer);

    //push layer
    layerManager->pushLayer("menuLayer");
    
//    U4DEngine::U4DDebugger *debugger=U4DEngine::U4DDebugger::sharedInstance();
//    debugger->setEnableDebugger(true, this);
    
}

void LevelOneWorld::actionOnButtonA(){
    
    Ball *ball=Ball::sharedInstance();
    
    if(buttonA->getIsPressed()){
    
    }else if (buttonA->getIsReleased()){
        
        ball->translateTo(ballInitPosition);
        players[0]->translateTo(player0InitPosition);
        players[1]->translateTo(player1InitPosition);
        players[2]->translateTo(player2InitPosition);
        
        players[0]->changeState(PlayerStateIdle::sharedInstance());
        players[1]->changeState(PlayerStateIdle::sharedInstance());
        players[2]->changeState(PlayerStateIdle::sharedInstance());
        
        Team *team=players[0]->getTeam();
        team->setControllingPlayer(players[0]);
    }
    
}

void LevelOneWorld::update(double dt){
    
//    //get the ball position
//    Ball *ball=Ball::sharedInstance();
//
//    U4DEngine::U4DVector2n ballPosition(ball->getAbsolutePosition().x,ball->getAbsolutePosition().z);
//
//    ballPosition.x/=80.0;
//    ballPosition.y/=45.0;
//
//    U4DVector4n param0(ballPosition.x,ballPosition.y,0.0,0.0);
//    playerVisualizerShader->updateShaderParameterContainer(0, param0);
//
//    //index used for the shader entity container
//    int index=1;
//
//    for(const auto &n:teamA->getPlayers()){
//
//        U4DEngine::U4DVector2n playerPos(n->getAbsolutePosition().x,n->getAbsolutePosition().z);
//
//        playerPos.x/=80.0;
//        playerPos.y/=45.0;
//
//        U4DVector4n param(playerPos.x,playerPos.y,0.0,0.0);
//        playerVisualizerShader->updateShaderParameterContainer(index, param);
//
//        index++;
//    }
    
    
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
//
//
//        PathAnalyzer *pathAnalyzer=PathAnalyzer::sharedInstance();
//
//        //send size of path
//        U4DEngine::U4DVector4n navParam0(pathAnalyzer->getNavigationPath().size(),0.0,0.0,0.0);
//        navigationMapShader->updateShaderParameterContainer(0, navParam0);
//
//        int p=1;
//
//        //This print the computed path, but the path does not contain the target position
//        for(auto &n:pathAnalyzer->getNavigationPath()){
//
//            U4DEngine::U4DVector4n navParam(n.pointA.x/80.0,n.pointA.z/45.0,n.pointB.x/80.0,n.pointB.z/45.0);
//            navigationMapShader->updateShaderParameterContainer(p, navParam);
//
//            p++;
//
//        }
}

void LevelOneWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(65.0f, director->getAspect(), 0.01f, 1000.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-100.0f, 100.0f, -100.0f, 100.0f, -100.0f, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPosition(0.0,15.0,-15.0);
    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DDirectionalLight *light=U4DDirectionalLight::sharedInstance(); 
    light->translateTo(10.0,20.0,-10.0);
    U4DEngine::U4DVector3n diffuse(1.0,1.0,1.0);
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




