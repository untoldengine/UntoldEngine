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

#include "U4DSkybox.h"
#include "U4DModelPipeline.h"


#include "U4DPlayer.h"
#include "U4DFoot.h"
#include "U4DField.h"
#include "U4DGoalPost.h"
#include "U4DBall.h"
#include "U4DPlayerStateIdle.h"
#include "U4DGameConfigs.h"

#include "U4DEntityFactory.h"
#include "U4DSerializer.h"


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
    
    //load the config values
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    gameConfigs->initConfigsMapKeys("dribblingBallSpeed","playerBiasMotionAccum","arriveMaxSpeed","arriveStopRadius","arriveSlowRadius","dribblingDirectionSlerpValue","shootingBallSpeed","passBallSpeed","passInterceptionParam","arriveJogMaxSpeed","arriveJogStopRadius","arriveJogSlowRadius","haltRadius","pursuitMaxSpeed","interceptMinRadius","freeMaxSpeed","freeStopRadius","freeSlowRadius","neighborPlayerSeparationDistance","neighborPlayerAlignmentDistance","neighborPlayerCohesionDistance","avoidanceMaxSpeed","fieldHalfWidth","fieldHalfLength","cellAnalyzerWidth","cellAnalyzerHeight","navPathRadius","navPredictTime","markArrivingMaxSpeed","markArriveStopRadius","markArriveSlowRadius","markAvoidanceMaxSpeed","markAvoidanceTimeParameter","markPursuitMaxSpeed","slidingTackleKick","slidingTackleVelocity",nullptr);
    
    gameConfigs->loadConfigsMapValues("gameconfigs.gravity");
    
    U4DEngine::U4DEntityFactory *entityFactory=U4DEngine::U4DEntityFactory::sharedInstance();
 
    entityFactory->registerClass<U4DPlayer>("U4DPlayer");
    entityFactory->registerClass<U4DField>("U4DField");
    entityFactory->registerClass<U4DGoalPost>("U4DGoalPost");
 
    
//    entityFactory->createModelInstance("player0", "player0.0", "U4DPlayer");
//    entityFactory->createModelInstance("field", "field0", "Field");
    

//    U4DModel *field=entityFactory->createAction("Field");
//
//     if(field->init("field")){
//
//         addChild(field);
//
//     }
    
    //deserialize
    U4DSerializer *serializer=U4DSerializer::sharedInstance();

    serializer->deserialize("scenefile.u4d");
    
//    U4DEngine::U4DPlayer *player=new U4DEngine::U4DPlayer();
//    if (player->init("player0")) {
//        addChild(player);
//
//        //render the right foot
//        U4DEngine::U4DFoot *rightFoot=new U4DEngine::U4DFoot();
//
//        std::string footName="rightfoot";
//        footName+=std::to_string(0);
//
//        if(rightFoot->init(footName.c_str())){
//
//            player->setFoot(rightFoot);
//
//        }
//
//        player->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
//    }
//
//
//
//    U4DEngine::U4DPlayer *oppositePlayers[5];
//
//    for(int i=0;i<5;i++){
//        std::string name="oppositeplayer";
//        name+=std::to_string(i);
//
//        oppositePlayers[i]=new U4DEngine::U4DPlayer();
//
//        if(oppositePlayers[i]->init(name.c_str())){
//            addChild(oppositePlayers[i]);
//
//            //render the right foot
//            U4DEngine::U4DFoot *rightFoot=new U4DEngine::U4DFoot();
//
//            std::string footName="rightfoot";
//            footName+=std::to_string(i+1);
//
//            if(rightFoot->init(footName.c_str())){
//
//                oppositePlayers[i]->setFoot(rightFoot);
//
//            }
//        }
//
//        oppositePlayers[i]->changeState(U4DPlayerStateIdle::sharedInstance());
//    }
//
//    Field *field=new Field();
//    if(field->init("field")){
//        addChild(field);
//    }

    

//    U4DEngine::U4DModel *fieldGoals[2];
//
//    for(int i=0;i<sizeof(fieldGoals)/sizeof(fieldGoals[0]);i++){
//
//        std::string name="fieldgoal";
//
//        name+=std::to_string(i);
//
//        fieldGoals[i]=new U4DEngine::U4DModel();
//
//        if(fieldGoals[i]->loadModel(name.c_str())){
//
//
//            fieldGoals[i]->loadRenderingInformation();
//
//            addChild(fieldGoals[i]);
//        }
//
//    }
//
//    U4DEngine::U4DModel *bleachers[4];
//
//    for(int i=0;i<sizeof(bleachers)/sizeof(bleachers[0]);i++){
//
//        std::string name="bleacher";
//
//        name+=std::to_string(i);
//
//        bleachers[i]=new U4DEngine::U4DModel();
//
//        if(bleachers[i]->loadModel(name.c_str())){
//
//
//            bleachers[i]->loadRenderingInformation();
//
//            addChild(bleachers[i]);
//        }
//
//    }
//
//
    
    
    
//    //initialize the skybox
//    U4DEngine::U4DSkybox *skybox=new U4DEngine::U4DSkybox();
//
//    skybox->initSkyBox(100.0,"LeftImage.png","RightImage.png","TopImage.png","BottomImage.png","FrontImage.png", "BackImage.png");
//
//    //add the skybox to the scenegraph with a z-depth of -1
//
//    addChild(skybox,-1);
//
}


void SandboxWorld::update(double dt){
    
    
}

//Sets the configuration for the engine: Perspective view, shadows, light
void SandboxWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.001f, 400.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-100.0f, 100.0f, -100.0f, 100.0f, -100.0f, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    U4DEngine::U4DVector3n cameraPosition(0.0,35.0,-42.0);

    
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
