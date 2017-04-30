//
//  U11PlayerRunToStealState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/29/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerRunToStealState_hpp
#define U11PlayerRunToStealState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerRunToStealState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerRunToStealState();
    
    ~U11PlayerRunToStealState();
    
public:
    
    static U11PlayerRunToStealState* instance;
    
    static U11PlayerRunToStealState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerRunToStealState_hpp */
