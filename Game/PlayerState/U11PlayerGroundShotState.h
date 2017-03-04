//
//  U11PlayerGroundShotState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerForwardKickState_hpp
#define U11PlayerForwardKickState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerGroundShotState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerGroundShotState();
    
    ~U11PlayerGroundShotState();
    
public:
    
    static U11PlayerGroundShotState* instance;
    
    static U11PlayerGroundShotState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
};
#endif /* U11PlayerForwardKickState_hpp */
