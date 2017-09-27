//
//  U11PlayerRunState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerRunState_hpp
#define U11PlayerRunState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerRunState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerRunState();
    
    ~U11PlayerRunState();
    
public:
    
    static U11PlayerRunState* instance;
    
    static U11PlayerRunState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};

#endif /* U11PlayerRunState_hpp */
