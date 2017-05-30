//
//  U11PlayerHaltBallState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerHaltBallState_hpp
#define U11PlayerHaltBallState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerHaltBallState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerHaltBallState();
    
    ~U11PlayerHaltBallState();
    
public:
    
    static U11PlayerHaltBallState* instance;
    
    static U11PlayerHaltBallState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerAdjustBallPositionState_hpp */
