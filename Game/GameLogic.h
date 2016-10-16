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
#include "MyCharacter.h"


namespace U4DEngine {
    class U4DTouches;
}

class GameLogic:public U4DEngine::U4DGameModel{
public:
    MyCharacter *ninja;
    kGameEntityState gameEntityState;
    
    GameLogic(){};
    ~GameLogic(){};
    
    void update(double dt);
    void init();
    
    void controllerAction(void* uControllerAction);
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
