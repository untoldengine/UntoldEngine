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

#include "GameLogic.h"

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
    
    ball=new U11Ball();
    ball->init("ball", "blenderscript.u4d");
    
    field=new U11Field();
    field->init("field0", "blenderscript.u4d");

    emelecPlayer10=new U11Player();
    emelecPlayer10->init("pele", "playerscript.u4d");
    
    emelecPlayer10->subscribeTeam(emelec);
    
    emelecPlayer11=new U11Player();
    emelecPlayer11->init("pele", "playerscript.u4d");
    
    emelecPlayer11->subscribeTeam(emelec);
    
    emelecPlayer9=new U11Player();
    emelecPlayer9->init("pele", "playerscript.u4d");
    
    emelecPlayer9->subscribeTeam(emelec);
    
    //opposite team
    barcelonaPlayer10=new U11Player();
    barcelonaPlayer10->init("pele", "oppositeplayerscript.u4d");
    
    barcelonaPlayer10->subscribeTeam(barcelona);
    
    barcelonaPlayer11=new U11Player();
    barcelonaPlayer11->init("pele", "oppositeplayerscript.u4d");
    
    barcelonaPlayer11->subscribeTeam(barcelona);
    
    //set ball entity
    field->setSoccerBall(ball);
    
    emelec->setSoccerBall(ball);
    
    barcelona->setSoccerBall(ball);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(ball);
    
    addChild(field);

    addChild(emelecPlayer10);
    
    addChild(emelecPlayer11);
    
    addChild(emelecPlayer9);
    
    addChild(barcelonaPlayer10);
    
    addChild(barcelonaPlayer11);
    
    //set the team
    GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());
    
    gameModel->setTeamToControl(emelec);
    
    
    //set the ball position
    ball->translateBy(-25.0, 0.0, 15.0);
    //set the player position
    
    emelecPlayer10->translateBy(-40.0, emelecPlayer10->getModelDimensions().y/2.0+1.3, 0.0);
    
    emelecPlayer11->translateBy(0.0, emelecPlayer11->getModelDimensions().y/2.0+1.3, -20.0);
    
    emelecPlayer9->translateBy(40.0, emelecPlayer9->getModelDimensions().y/2.0+1.3, 15.0);
    
    barcelonaPlayer10->translateBy(-10.0, barcelonaPlayer10->getModelDimensions().y/2+1.3, 0.0);
    
    barcelonaPlayer11->translateBy(0.0, barcelonaPlayer10->getModelDimensions().y/2+1.3, 20.0);
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->followModel(ball, 0.0, 80.0, 100.0);
    

}





