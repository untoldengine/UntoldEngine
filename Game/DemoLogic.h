//
//  DemoLogic.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef DemoLogic_hpp
#define DemoLogic_hpp

#include <stdio.h>
#include "U4DGameModel.h"
#include "UserCommonProtocols.h"
#include "U4DNavigation.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "Hero.h"
#include "Enemy.h"

class DemoLogic:public U4DEngine::U4DGameModel{
    
private:
    
    Hero *pPlayer;
    
    Enemy *pEnemies[3];
    
    U4DEngine::U4DVector3n motionAccumulator;
    
    float angleAccumulator;
    
    MouseMovementDirection mouseMovementDirection;
    
    U4DEngine::U4DNavigation *navigation;
    
    //declare the callback with the class name
    U4DEngine::U4DCallback<DemoLogic> *navigationScheduler;
    
    //declare the timer
    U4DEngine::U4DTimer *navigationTimer;
    
public:
    
    DemoLogic();
    
    ~DemoLogic();
    
    void update(double dt);
    
    void init();
    
    void computeNavigation();
    
    void receiveUserInputUpdate(void *uData);
    
};
#endif /* DemoLogic_hpp */
