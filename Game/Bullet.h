//
//  Bullet.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Bullet_hpp
#define Bullet_hpp

#include <stdio.h>
#include <string>
#include "U4DGameObject.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DWorld.h"

class Bullet:public U4DEngine::U4DGameObject {
    
private:
    GameEntityState entityState;
    U4DEngine::U4DCallback<Bullet>* scheduler;
    U4DEngine::U4DTimer *timer;
    
    bool shouldDestroy;
    
    U4DEngine::U4DWorld *world;
    
public:
    Bullet();
    
    ~Bullet();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
    void setShootingParameters(U4DEngine::U4DWorld *uWorld,U4DEngine::U4DVector3n &uPosition, U4DEngine::U4DVector3n &uViewDirection);
    
    void shoot();
    
    void selfDestroy();
    
    
};

#endif /* Bullet_hpp */
