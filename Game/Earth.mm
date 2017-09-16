//
//  Earth.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "Earth.h"

#include "CommonProtocols.h"

#include <stdio.h>

#include "U4DDirector.h"

#include "U4DMatrix3n.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DLights.h"
#include "U4DLogger.h"


#include "GameLogic.h"
#include "U11Ball.h"
#include "U11Field.h"
#include "U11Player.h"
#include "U11FieldGoal.h"
#include "U11Team.h"

#include "U11Formation442.h"
#include "U11FormationInterface.h"
#include "U11PlayerIndicator.h"

#include "U11AttackSystemInterface.h"
#include "U11DefenseSystemInterface.h"
#include "U11RecoverSystemInterface.h"
#include "U11AIAttackStrategyInterface.h"

#include "U11AttackAISystem.h"
#include "U11AttackManualSystem.h"
#include "U11DefenseAISystem.h"
#include "U11DefenseManualSystem.h"
#include "U11RecoverAISystem.h"
#include "U11RecoverManualSystem.h"
#include "U11AIAttackStrategy.h"

using namespace U4DEngine;

void Earth::init(){
    
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,20.0,-40.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    //setEnableGrid(true);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    //compute perspective space
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.1f, 500.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //compute orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicSpace(-100.0, 100.0, -100.0, 100.0, -100.0, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(0.0,40.0,0.0);
    
    addChild(light);
    
    camera->viewInDirection(origin);

    light->viewInDirection(origin);
    
    
    
    U11FormationInterface *emelecFormation=new U11Formation442();
    U11FormationInterface *barcelonaFormation=new U11Formation442();
    
    U11DefenseSystemInterface *defenseAISystem=new U11DefenseAISystem();
    U11DefenseSystemInterface *defenseManualSystem=new U11DefenseManualSystem();
    
    
    U11AttackSystemInterface *attackAISystem=new U11AttackAISystem();
    U11AttackSystemInterface *attackManualSystem=new U11AttackManualSystem();
    
    U11RecoverSystemInterface *recoverAISystem=new U11RecoverAISystem();
    U11RecoverSystemInterface *recoverManualSystem=new U11RecoverManualSystem();
    
    U11AIAttackStrategyInterface *attackStrategy=new U11AIAttackStrategy();
    
    
    emelec=new U11Team(this, attackManualSystem, defenseManualSystem,recoverManualSystem, attackStrategy ,-1, emelecFormation);
    
    barcelona=new U11Team(this,attackAISystem, defenseAISystem, recoverAISystem, nullptr ,1, barcelonaFormation);
    
    emelec->setOppositeTeam(barcelona);
    barcelona->setOppositeTeam(emelec);
    
    ball=new U11Ball();
    ball->init("ball", "blenderscript.u4d");
    
    field=new U11Field();
    field->init("field", "blenderscript.u4d");
    
    emelecPlayer10=new U11Player();
    emelecPlayer10->init("player", "playerscript.u4d");
    
    emelecPlayer10->subscribeTeam(emelec);
    
    emelecPlayer11=new U11Player();
    emelecPlayer11->init("player", "playerscript.u4d");
    
    emelecPlayer11->subscribeTeam(emelec);
    /*
    emelecPlayer9=new U11Player();
    emelecPlayer9->init("player", "playerscript.u4d");
    
    emelecPlayer9->subscribeTeam(emelec);
    
    emelecPlayer8=new U11Player();
    emelecPlayer8->init("player", "playerscript.u4d");
    
    emelecPlayer8->subscribeTeam(emelec);
    
    emelecPlayer7=new U11Player();
    emelecPlayer7->init("player", "playerscript.u4d");
    
    emelecPlayer7->subscribeTeam(emelec);
    
    
    emelecPlayer6=new U11Player();
    emelecPlayer6->init("player", "playerscript.u4d");

    emelecPlayer6->subscribeTeam(emelec);

    emelecPlayer5=new U11Player();
    emelecPlayer5->init("player", "playerscript.u4d");

    emelecPlayer5->subscribeTeam(emelec);

    emelecPlayer4=new U11Player();
    emelecPlayer4->init("player", "playerscript.u4d");

    emelecPlayer4->subscribeTeam(emelec);

    emelecPlayer3=new U11Player();
    emelecPlayer3->init("player", "playerscript.u4d");

    emelecPlayer3->subscribeTeam(emelec);

    emelecPlayer2=new U11Player();
    emelecPlayer2->init("player", "playerscript.u4d");

    emelecPlayer2->subscribeTeam(emelec);
    */
    
    //opposite team
    
    barcelonaPlayer10=new U11Player();
    barcelonaPlayer10->init("player", "oppositeplayerscript.u4d");
    
    barcelonaPlayer10->subscribeTeam(barcelona);
   /*
    barcelonaPlayer11=new U11Player();
    barcelonaPlayer11->init("player", "oppositeplayerscript.u4d");
    
    barcelonaPlayer11->subscribeTeam(barcelona);
    
    barcelonaPlayer9=new U11Player();
    barcelonaPlayer9->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer9->subscribeTeam(barcelona);

    barcelonaPlayer8=new U11Player();
    barcelonaPlayer8->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer8->subscribeTeam(barcelona);

    barcelonaPlayer7=new U11Player();
    barcelonaPlayer7->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer7->subscribeTeam(barcelona);


    barcelonaPlayer6=new U11Player();
    barcelonaPlayer6->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer6->subscribeTeam(barcelona);


    barcelonaPlayer5=new U11Player();
    barcelonaPlayer5->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer5->subscribeTeam(barcelona);

    barcelonaPlayer4=new U11Player();
    barcelonaPlayer4->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer4->subscribeTeam(barcelona);


    barcelonaPlayer3=new U11Player();
    barcelonaPlayer3->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer3->subscribeTeam(barcelona);


    barcelonaPlayer2=new U11Player();
    barcelonaPlayer2->init("player", "oppositeplayerscript.u4d");

    barcelonaPlayer2->subscribeTeam(barcelona);
 
    */
    
    //set ball entity
    field->setSoccerBall(ball);
    
    emelec->setSoccerBall(ball);
    
    barcelona->setSoccerBall(ball);
    
    //set the field goals
    fieldGoal1=new U11FieldGoal();
    fieldGoal1->init("fieldgoal1","blenderscript.u4d");
    
    fieldGoal2=new U11FieldGoal();
    fieldGoal2->init("fieldgoal2","blenderscript.u4d");
    
    //set field goals to team
    emelec->setFieldGoal(fieldGoal2);
    
    barcelona->setFieldGoal(fieldGoal1);
    
    addChild(ball);
    
    addChild(field);
    
    addChild(emelecPlayer10);
    
    addChild(emelecPlayer11);
    /*
    addChild(emelecPlayer9);
    
    addChild(emelecPlayer8);
    
    addChild(emelecPlayer7);
    
    addChild(emelecPlayer6);

    addChild(emelecPlayer5);

    addChild(emelecPlayer4);

    addChild(emelecPlayer3);

    addChild(emelecPlayer2);
    */
    
    
    addChild(barcelonaPlayer10);
  /*
    addChild(barcelonaPlayer11);
    
    addChild(barcelonaPlayer9);

    addChild(barcelonaPlayer8);

    addChild(barcelonaPlayer7);

    addChild(barcelonaPlayer6);

    addChild(barcelonaPlayer5);

    addChild(barcelonaPlayer4);

    addChild(barcelonaPlayer3);

    addChild(barcelonaPlayer2);
 
    
    addChild(fieldGoal1);
    
    addChild(fieldGoal2);
    
  */  
    //set the player indicator
    /*
    playerIndicator=new U11PlayerIndicator(emelec);
    playerIndicator->init("indicator", "miscellaneousscript.u4d");
    
    addChild(playerIndicator);
    */
    //set the team
    GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());
    
    gameModel->setTeamToControl(emelec);
    
    //set the player position
    
    emelec->translateTeamToFormationPosition();
    barcelona->translateTeamToFormationPosition();
    
    
    float yPos=emelecPlayer10->getModelDimensions().y/2.0+0.3;
    
    emelecPlayer10->translateTo(-1.0, yPos, 0.0);
    emelecPlayer11->translateTo(14.0,yPos, -5.5);
   
}

void Earth::update(double dt){

    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    
    camera->followModel(ball, 0.0, 15.0, -30.0);
    
    //camera->followModel(ball, 0.0, 0.0, -10.0);
}





