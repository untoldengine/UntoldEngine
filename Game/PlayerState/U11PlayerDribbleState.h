//
//  U11PlayerDribbleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerDribbleState_hpp
#define U11PlayerDribbleState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerDribbleState:public U11PlayerStateInterface {
    
protected:
    
    U11PlayerDribbleState();
    
    ~U11PlayerDribbleState();
    
public:
    
    static U11PlayerDribbleState* instance;
    
    static U11PlayerDribbleState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};

#endif /* U11PlayerDribbleState_hpp */
