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
#include "GuardianModel.h"
#include "UserCommonProtocols.h"
#include "U4DText.h"

namespace U4DEngine {
    class U4DTouches;
    class U4DButton;
    class U4DJoyStick;
}

class GameLogic:public U4DEngine::U4DGameModel{
    
private:
    
    GuardianModel *guardian;
    U4DEngine::U4DText *text;
    int points;
    
public:
    
    GameLogic();
    
    ~GameLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveTouchUpdate(void *uData);
    
    void setGuardian(GuardianModel *uGuardian);
    
    void setText(U4DEngine::U4DText *uText);
    
    void increasePoints();
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
