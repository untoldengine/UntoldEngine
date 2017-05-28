//
//  U11PlayerHaltInterceptState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerHaltInterceptState_hpp
#define U11PlayerHaltInterceptState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerHaltInterceptState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerHaltInterceptState();
    
    ~U11PlayerHaltInterceptState();
    
public:
    
    static U11PlayerHaltInterceptState* instance;
    
    static U11PlayerHaltInterceptState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};

#endif /* U11PlayerHaltInterceptState_hpp */
