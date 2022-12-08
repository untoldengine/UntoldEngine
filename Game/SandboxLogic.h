//
//  SandboxLogic.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef DebugLogic_hpp
#define DebugLogic_hpp

#include <stdio.h>
#include "U4DGameLogic.h"
#include "U4DModel.h"
#include "U4DPlayer.h"
#include "U4DTeam.h"
#include "U4DField.h"
#include "UserCommonProtocols.h"
#include "U4DPolygonMesh.h"
class SandboxLogic:public U4DEngine::U4DGameLogic{
    
private:
    
    U4DEngine::U4DPlayer *pPlayer;
    U4DEngine::U4DTeam *teamA;
    U4DEngine::U4DTeam *teamB;
    U4DEngine::U4DField *field;
    U4DEngine::U4DVector3n dribblingDirection;
    U4DEngine::U4DPolygonMesh *mesh;
    float angleAccumulator;
    
    MouseMovementDirection mouseMovementDirection;
    U4DEngine::U4DVector3n mouseDirection;
    U4DEngine::U4DVector3n playerMotionAccumulator;
    
    bool startGame;
    bool aKeyFlag;
    bool wKeyFlag;
    bool sKeyFlag;
    bool dKeyFlag;
    
    
public:
    
    SandboxLogic();
    
    ~SandboxLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
    
    
};
#endif /* DebugLogic_hpp */
