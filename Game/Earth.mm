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
#include "U4DButton.h"
#include "U4DSkyBox.h"
#include "U4DTouches.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DSprite.h"
#include "U4DLights.h"
#include "U4DLogger.h"
#include "U11Ball.h"
#include "U11Field.h"
#include "U11Player.h"
#include "U11Team.h"
#include "U11FieldGoal.h"

#include "GameLogic.h"
#include "U11Formation.h"
#include "U11FormationInterface.h"
#include "U11212Formation.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 80.0, 100.0);
    camera->rotateBy(-36.0, 0.0, 0.0);
    
    setName("earth");
    
    enableShadows();
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    emelec=new U11Team();
    
    barcelona=new U11Team();
    
    emelec->setOppositeTeam(barcelona);
    barcelona->setOppositeTeam(emelec);
    
    ball=new U11Ball();
    ball->init("ball", "blenderscript.u4d");
    
    field=new U11Field();
    field->init("field", "blenderscript.u4d");

    emelecPlayer10=new U11Player();
    emelecPlayer10->init("pele", "playerscript.u4d");
    
    emelecPlayer10->subscribeTeam(emelec);
    
    emelecPlayer11=new U11Player();
    emelecPlayer11->init("pele", "playerscript.u4d");
    
    emelecPlayer11->subscribeTeam(emelec);
    
    emelecPlayer9=new U11Player();
    emelecPlayer9->init("pele", "playerscript.u4d");
    
    emelecPlayer9->subscribeTeam(emelec);
    
    emelecPlayer8=new U11Player();
    emelecPlayer8->init("pele", "playerscript.u4d");
    
    emelecPlayer8->subscribeTeam(emelec);
    
    emelecPlayer7=new U11Player();
    emelecPlayer7->init("pele", "playerscript.u4d");
    
    emelecPlayer7->subscribeTeam(emelec);
    
    //opposite team
    barcelonaPlayer10=new U11Player();
    barcelonaPlayer10->init("pele", "oppositeplayerscript.u4d");
    
    barcelonaPlayer10->subscribeTeam(barcelona);
    
    barcelonaPlayer11=new U11Player();
    barcelonaPlayer11->init("pele", "oppositeplayerscript.u4d");
    
    barcelonaPlayer11->subscribeTeam(barcelona);
    
    barcelonaPlayer9=new U11Player();
    barcelonaPlayer9->init("pele", "oppositeplayerscript.u4d");
    
    barcelonaPlayer9->subscribeTeam(barcelona);
    
    barcelonaPlayer8=new U11Player();
    barcelonaPlayer8->init("pele", "oppositeplayerscript.u4d");
    
    barcelonaPlayer8->subscribeTeam(barcelona);
    
    barcelonaPlayer7=new U11Player();
    barcelonaPlayer7->init("pele", "oppositeplayerscript.u4d");
    
    barcelonaPlayer7->subscribeTeam(barcelona);
    
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
    
    
    //TEMP
    barcelona->setDefendingPlayer(barcelonaPlayer9);
    
    //set field side
    emelec->setFieldSide("leftside");
    barcelona->setFieldSide("rightside");
    
    //set formation
    U11FormationInterface *formation212=new U11212Formation();
    
    emelec->setTeamFormation(formation212);
    barcelona->setTeamFormation(formation212);
    
    emelec->assignTeamFormation(field);
    barcelona->assignTeamFormation(field);
    
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(ball);
    
    addChild(field);

    addChild(emelecPlayer10);
    
    addChild(emelecPlayer11);
    
    addChild(emelecPlayer9);
    
    addChild(emelecPlayer8);
    
    addChild(emelecPlayer7);
    
    addChild(barcelonaPlayer10);
    
    addChild(barcelonaPlayer11);
    
    addChild(barcelonaPlayer9);
    
    addChild(barcelonaPlayer8);
    
    addChild(barcelonaPlayer7);
    
    addChild(fieldGoal1);
    
    addChild(fieldGoal2);
    
    //set the team
    GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());
    
    gameModel->setTeamToControl(emelec);
    
    
    //set the ball position
    ball->translateBy(-25.0, 0.0, 15.0);
    //set the player position
    
    emelec->positionPlayersPerHomeFormation();
    barcelona->positionPlayersPerHomeFormation();
    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->followModel(ball, 0.0, 80.0, 100.0);
    

}





