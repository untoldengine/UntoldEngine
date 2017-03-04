//
//  U11PlayerReverseKickState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/24/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerReverseKickState_hpp
#define U11PlayerReverseKickState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerReverseKickState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerReverseKickState();
    
    ~U11PlayerReverseKickState();
    
public:
    
    static U11PlayerReverseKickState* instance;
    
    static U11PlayerReverseKickState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerReverseKickState_hpp */
