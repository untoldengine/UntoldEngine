//
//  DebugWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "DebugWorld.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DResourceLoader.h"
#include "UserCommonProtocols.h"
#include "U4DCameraInterface.h"
#include "U4DCameraBasicFollow.h"
#include "Player.h"
#include "Ball.h"
#include "Team.h"
#include "DebugLogic.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateGroupNav.h"

using namespace U4DEngine;

DebugWorld::DebugWorld(){
    
}

DebugWorld::~DebugWorld(){
    
}

void DebugWorld::init(){
    
    /*----DO NOT REMOVE. THIS IS REQUIRED-----*/
    //Configures the perspective view, shadows, lights and camera.
    setupConfiguration();
    /*----END DO NOT REMOVE.-----*/
    
    //The following code snippets loads scene data, renders the characters and skybox.
    
    /*---LOAD SCENE ASSETS HERE--*/
    //The U4DResourceLoader is in charge of loading the binary file containing the scene data
    U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();
    
    //Load binary file with scene data
    resourceLoader->loadSceneData("debugScene.u4d");
//
//    //Load binary file with texture data
    resourceLoader->loadTextureData("debugTextures.u4d");
    
    resourceLoader->loadAnimationData("runningAnimation.u4d");
    
    resourceLoader->loadAnimationData("idleAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightdribbleAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightsolehaltAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightpassAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightshotAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightstandtackleAnimation.u4d");
    
    resourceLoader->loadAnimationData("rightforwardcontainAnimation.u4d");
    
    resourceLoader->loadAnimationData("righttapAnimation.u4d");
    
    ground=new U4DEngine::U4DGameObject();

    if(ground->loadModel("field")){

        //ground->setShader("vertexFieldBoundShader","fragmentFieldBoundShader");
        
        //ground->setShader("vertexBallPredictionShader","fragmentBallPredictionShader");
        //ground->setShader("vertexIndicatorDirectionShader","fragmentIndicatorDirectionShader");
        ground->setShader("vertexFieldShader", "fragmentFieldShader");
        //set shadows
        ground->setEnableShadow(true);
        
        ground->setNormalMapTexture("FieldNormalMap.png");
        
        //send info to gpu
        ground->loadRenderingInformation();

        //add to scenegraph
        addChild(ground);
    }
    
    //render the ball
    Ball *ball=Ball::sharedInstance();
    
    if (ball->init("ball2")) {
        
        addChild(ball);
        
    }
    
    //Initialize both teams
    Team *teamA=new Team();
    Team *teamB=new Team();
    
    DebugLogic *debugLogic=dynamic_cast<DebugLogic*>(getGameModel());
    
    debugLogic->setControllingTeam(teamA);
    
    Player *players[3];
    
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
            
            teamA->addPlayer(players[i]); 
        }

    }
    
    players[0]->changeState(PlayerStateChase::sharedInstance());
    
    players[1]->changeState(PlayerStateGroupNav::sharedInstance());
    
    players[2]->changeState(PlayerStateGroupNav::sharedInstance());
    
    
    Player *oppositePlayers[3];

    for(int i=0;i<sizeof(oppositePlayers)/sizeof(oppositePlayers[0]);i++){

        std::string name="oppositeplayer";
        name+=std::to_string(i);

        oppositePlayers[i]=new Player();

        if(oppositePlayers[i]->init(name.c_str())){

            addChild(oppositePlayers[i]);

            teamB->addPlayer(oppositePlayers[i]);

        }

    }
    
    
    //Create Player Indicator shader
    playerIndicatorShader=new U4DEngine::U4DShaderEntity(1);

    playerIndicatorShader->setShader("vertexInstructionsShader", "fragmentInstructionsShader");

    U4DDirector *director=U4DDirector::sharedInstance();

    playerIndicatorShader->setShaderDimension(director->getDisplayWidth(), director->getDisplayHeight());

    playerIndicatorShader->loadRenderingInformation();

    addChild(playerIndicatorShader,-10);

    debugLogic->setPlayerIndicator(playerIndicatorShader);
    
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
    
    //Instantiate the camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    //Instantiate the camera interface and the type of camera you desire
    U4DEngine::U4DCameraInterface *cameraBasicFollow=U4DEngine::U4DCameraBasicFollow::sharedInstance();

    //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
    cameraBasicFollow->setParameters(ball,0.0,25.0,-50.0);

    //set the camera behavior
    camera->setCameraBehavior(cameraBasicFollow);
  
//
//    //Animation for astronaut
//    //load binary file with animation data
//    resourceLoader->loadAnimationData("debugAnimation.u4d");
//
//    //Line 2. Create an instance of U4DGameObject type
//    U4DEngine::U4DGameObject *player=new U4DEngine::U4DGameObject();
//
//    //Line 3. Load attribute (rendering information) into the game entity
//    if (player->loadModel("player0")) {
//
//        //Line 4. Load rendering information into the GPU
//        player->loadRenderingInformation();
//
//        //Line 5. Add astronaut to the scenegraph
//        addChild(player);
//
//    }
    
    //Line 2. Create an Animation object and link it to the 3D model
//    U4DEngine::U4DAnimation *testAnimation=new U4DEngine::U4DAnimation(player);
//
//    //Line 3. Load animation data into the animation object
//    if(player->loadAnimationToModel(testAnimation, "walking")){
//
//        //If animation data was successfully loaded, you can set other parameters here. For now, we won't do this.
//
//    }
//
//    //Line 4. Check if the animation object exist and play the animation
//    if (testAnimation!=nullptr) {
//
//        testAnimation->play();
//
//    }
    
}

void DebugWorld::update(double dt){
 
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

//Sets the configuration for the engine: Perspective view, shadows, light
void DebugWorld::setupConfiguration(){
    
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
    U4DEngine::U4DVector3n cameraPosition(0.0,10.0,-10.0);
    
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
