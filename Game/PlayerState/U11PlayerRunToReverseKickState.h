//
//  U11PlayerRunToReverseKickState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerRunToReverseKickState_hpp
#define U11PlayerRunToReverseKickState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerRunToReverseKickState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerRunToReverseKickState();
    
    ~U11PlayerRunToReverseKickState();
    
public:
    
    static U11PlayerRunToReverseKickState* instance;
    
    static U11PlayerRunToReverseKickState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerRunToReverseKickState_hpp */
