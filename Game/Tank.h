//
//  Tank.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Tank_hpp
#define Tank_hpp

#include <stdio.h>
#include <string>
#include "Artillery.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DWorld.h"

class TankGun;

class Tank:public Artillery{
    
private:

    TankGun *tankGun;
    U4DEngine::U4DCallback<Tank>* scheduler;
    U4DEngine::U4DTimer *timer;
    
    U4DEngine::U4DCallback<Tank>* shootingScheduler;
    U4DEngine::U4DTimer *shootingTimer;
    
    bool isDestroyed;
    
    U4DEngine::U4DWorld *world;
    
public:

    Tank();
    
    ~Tank();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void setSelfDestroyTimer();
    
    void selfDestroy();
    
    void setWorld(U4DEngine::U4DWorld *uWorld);
    
    void shoot();
    
    U4DEngine::U4DVector3n getAimVector();
};

#endif /* Tank_hpp */
