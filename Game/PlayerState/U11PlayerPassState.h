//
//  U11PlayerPassState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerPassState_hpp
#define U11PlayerPassState_hpp

#include <stdio.h>

#include "U11PlayerStateInterface.h"

class U11PlayerPassState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerPassState();
    
    ~U11PlayerPassState();
    
public:
    
    static U11PlayerPassState* instance;
    
    static U11PlayerPassState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};


#endif /* U11PlayerPassState_hpp */
