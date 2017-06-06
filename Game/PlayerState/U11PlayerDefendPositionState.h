//
//  U11PlayerDefendPositionState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerDefendPositionState_hpp
#define U11PlayerDefendPositionState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerDefendPositionState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerDefendPositionState();
    
    ~U11PlayerDefendPositionState();
    
public:
    
    static U11PlayerDefendPositionState* instance;
    
    static U11PlayerDefendPositionState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerRunToDefendState_hpp */
