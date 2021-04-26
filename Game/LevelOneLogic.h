//
//  LevelOneLogic.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__GameLogic__
#define __UntoldEngine__GameLogic__

#include <iostream>
#include "U4DGameModel.h"
#include "Player.h"
#include "U4DShaderEntity.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DText.h"

class Team;

class LevelOneLogic:public U4DEngine::U4DGameModel{
    
private:
    
    //declare the callback with the class name
    U4DEngine::U4DCallback<LevelOneLogic> *outOfBoundScheduler;

    //declare the timer
    U4DEngine::U4DTimer *outOfBoundTimer;
    
    //declare the callback with the class name
    U4DEngine::U4DCallback<LevelOneLogic> *messageLabelScheduler;

    //declare the timer
    U4DEngine::U4DTimer *messageLabelTimer;
    
    //declare the callback with the class name
    U4DEngine::U4DCallback<LevelOneLogic> *timeUpScheduler;

    //declare the timer
    U4DEngine::U4DTimer *timeUpTimer;
    
    //player
    Player *pPlayer;

    //controlling team
    Team *controllingTeam;
    
    //marking team
    Team *markingTeam;
    
    U4DEngine::U4DGameObject *pGround;
    
    bool stickActive;
    
    U4DEngine::U4DVector3n stickDirection;
    
    U4DEngine::U4DShaderEntity *pPlayerIndicator;
    
    MouseMovementDirection mouseMovementDirection;
    
    U4DEngine::U4DVector2n currentMousePosition;
    
    bool showDirectionLine;
    
    std::vector<U4DEngine::U4DVector4n> voronoiSegments;
    
    int goalCount;
    
    U4DEngine::U4DText *gameClock;
    
    U4DEngine::U4DText *score;
    
    int clockTime;
    
    bool messagleLabelIsShown;
    
public:
    
    LevelOneLogic();
    
    ~LevelOneLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
    void setControllingTeam(Team *uTeam);
    
    void setMarkingTeam(Team *uTeam);
    
    void setPlayerIndicator(U4DEngine::U4DShaderEntity *uPlayerIndicator);
    
    void computeVoronoi();
    
    float clampVoronoi(float x, float upper, float lower);
    
    void outOfBound();
    
    bool teamsReady();
    
    void showGoalLabel();
    
    void showOutOfBoundLabel();
    
    void removeMessageLabel();
    
    void timesUp();
    
    void showGameOverLabel();
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
