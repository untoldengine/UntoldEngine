//
//  U4DBallStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBallStateManager_hpp
#define U4DBallStateManager_hpp

#include <stdio.h>
#include "U4DBallStateInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {

class U4DBall;

class U4DBallStateManager{
  
private:
    
    U4DBall *ball;
    
    U4DBallStateInterface *previousState;
    
    U4DBallStateInterface *currentState;
    
    U4DBallStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    U4DBallStateManager(U4DBall *uBall);
    
    ~U4DBallStateManager();
    
    void changeState(U4DBallStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(U4DBallStateInterface *uState);
    
    bool handleMessage(Message &uMsg);
    
    U4DBallStateInterface *getCurrentState();
    
    U4DBallStateInterface *getPreviousState();
    
    std::string getCurrentStateName();
    
};
}
#endif /* U4DBallStateManager_hpp */
