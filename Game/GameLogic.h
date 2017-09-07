//
//  GameLogic.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__GameLogic__
#define __UntoldEngine__GameLogic__

#include <iostream>
#include "U4DGameModel.h"
#include "UserCommonProtocols.h"
#include "U11Field.h"
#include "U11Player.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

namespace U4DEngine {
    class U4DTouches;
    class U4DButton;
    class U4DJoyStick;
}

class GameLogic:public U4DEngine::U4DGameModel{
public:
    
    U11Team *team;
    
    int buttonHoldTime;
    
    U4DEngine::U4DButton *buttonA;
    U4DEngine::U4DButton *buttonB;
    U4DEngine::U4DJoyStick *joystick;
    
    U4DEngine::U4DTimer *buttonHoldTimer;
    
    U4DEngine::U4DCallback<GameLogic> *scheduler;
    
    GameLogic();
    ~GameLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveTouchUpdate();
    
    void setTeamToControl(U11Team *uTeam);
    
    void increaseButtonHoldTime();
    
    void startButtonHoldTimer();
    
    void stopButtonHoldTimer();
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
