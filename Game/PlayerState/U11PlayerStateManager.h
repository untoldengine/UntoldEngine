//
//  U11PlayerStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerStateManager_hpp
#define U11PlayerStateManager_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11Player;

class U11PlayerStateManager {
    
private:
    
    U11Player *player;
    
    U11PlayerStateInterface *previousState;
    
    U11PlayerStateInterface *currentState;
    
    U11PlayerStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    U11PlayerStateManager(U11Player *uPlayer);
    
    ~U11PlayerStateManager();
    
    void changeState(U11PlayerStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(U11PlayerStateInterface *uState);
};

#endif /* U11PlayerStateManager_hpp */
