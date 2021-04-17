//
//  LevelOneWorld.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__Earth__
#define __UntoldEngine__Earth__

#include <iostream>
#include <vector>
#include "U4DWorld.h"
#include "U4DGameObject.h"
#include "U4DAnimation.h"
#include "U4DDynamicModel.h"
#include "Player.h"
#include "Team.h"
#include "U4DShaderEntity.h"
#include "U4DButton.h"

class LevelOneWorld:public U4DEngine::U4DWorld{

private:
    
    Team* teamA;
    Team* teamB;
    
    U4DEngine::U4DGameObject *ground;
    U4DEngine::U4DShaderEntity *playerVisualizerShader;
    U4DEngine::U4DShaderEntity *influenceMapShader;
    U4DEngine::U4DShaderEntity *navigationMapShader;
    U4DEngine::U4DShaderEntity *playerIndicatorShader;
    
    U4DEngine::U4DVector3n ballInitPosition;
    U4DEngine::U4DVector3n player0InitPosition;
    U4DEngine::U4DVector3n player1InitPosition;
    U4DEngine::U4DVector3n player2InitPosition;
    
    U4DEngine::U4DButton *buttonA;
    
    Player *players[1];
    
public:
   
    LevelOneWorld(){};
    ~LevelOneWorld();
    
    void init();
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
    void actionOnButtonA();
    
};

#endif /* defined(__UntoldEngine__Earth__) */
