//
//  U4DPlayerStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateManager_hpp
#define U4DPlayerStateManager_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {

class U4DPlayer;

class U4DPlayerStateManager{
  
private:
    
    U4DPlayer *player;
    
    U4DPlayerStateInterface *previousState;
    
    U4DPlayerStateInterface *currentState;
    
    U4DPlayerStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    U4DPlayerStateManager(U4DPlayer *uPlayer);
    
    ~U4DPlayerStateManager();
    
    void changeState(U4DPlayerStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(U4DPlayerStateInterface *uState);
    
    bool handleMessage(Message &uMsg);
    
    U4DPlayerStateInterface *getCurrentState();
    
    U4DPlayerStateInterface *getPreviousState();
    
};
}

#endif /* U4DPlayerStateManager_hpp */
