//
//  U11PlayerRecoverState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerRecoverState_hpp
#define U11PlayerRecoverState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerRecoverState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerRecoverState();
    
    ~U11PlayerRecoverState();
    
public:
    
    static U11PlayerRecoverState* instance;
    
    static U11PlayerRecoverState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerRecoverState_hpp */
