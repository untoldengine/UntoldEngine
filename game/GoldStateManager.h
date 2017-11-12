//
//  GoldStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef GoldStateManager_hpp
#define GoldStateManager_hpp

#include <stdio.h>
#include "GoldStateInterface.h"
#include "UserCommonProtocols.h"

class GoldAsset;

class GoldStateManager {
    
private:
    
    GoldAsset *gold;
    
    GoldStateInterface *previousState;
    
    GoldStateInterface *currentState;
    
    GoldStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    GoldStateManager(GoldAsset *uGuardian);
    
    ~GoldStateManager();
    
    void changeState(GoldStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(GoldStateInterface *uState);
    
    bool handleMessage(Message &uMsg);
    
    GoldStateInterface *getCurrentState();
    
};
#endif /* GoldStateManager_hpp */
