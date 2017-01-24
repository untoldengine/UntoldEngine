//
//  Rocket.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Rocket_hpp
#define Rocket_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

class Rock:public U4DEngine::U4DGameObject {
    
private:
    
    GameEntityState entityState;
    bool isDestroyed;
    U4DEngine::U4DCallback<Rock>* scheduler;
    U4DEngine::U4DTimer *timer;
    
public:
    
    Rock();
    
    ~Rock();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
    void selfDestroy();
    
};

#endif /* Rocket_hpp */
