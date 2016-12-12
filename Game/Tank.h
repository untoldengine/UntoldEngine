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


class TankGun;

class Tank:public Artillery{
    
private:

    TankGun *tankGun;
    
    U4DEngine::U4DCallback<Tank>* scheduler;
    
    U4DEngine::U4DTimer *selfDestroyTimer;
    U4DEngine::U4DTimer *shootingTimer;
    
public:

    Tank();
    
    ~Tank();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void selfDestroy();
    
    U4DEngine::U4DVector3n getAimVector();
};

#endif /* Tank_hpp */
