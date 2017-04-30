//
//  U11PlayerStealingState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerStealingState_hpp
#define U11PlayerStealingState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerStealingState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerStealingState();
    
    ~U11PlayerStealingState();
    
public:
    
    static U11PlayerStealingState* instance;
    
    static U11PlayerStealingState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerStealingState_hpp */
