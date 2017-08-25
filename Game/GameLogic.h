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

#include "SoccerPlayer.h"

namespace U4DEngine {
    class U4DTouches;
    class U4DButton;
    class U4DJoyStick;
    class U4DSpriteAnimation;

}

class GameLogic:public U4DEngine::U4DGameModel{
public:
    
    U4DEngine::U4DButton *buttonA;
    U4DEngine::U4DButton *buttonB;
    U4DEngine::U4DJoyStick *joystick;
    
    SoccerPlayer *player;
    
    U4DEngine::U4DSpriteAnimation *spriteAnimation;
    
    GameLogic();
    ~GameLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveTouchUpdate();
    
    void setMainPlayer(SoccerPlayer *uPlayer);
    
    void setSpriteAnim(U4DEngine::U4DSpriteAnimation *uSpriteAnimation);
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
