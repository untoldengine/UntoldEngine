//
//  U11PlayerOpenUpState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerOpenUpState_hpp
#define U11PlayerOpenUpState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerOpenUpState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerOpenUpState();
    
    ~U11PlayerOpenUpState();
    
public:
    
    static U11PlayerOpenUpState* instance;
    
    static U11PlayerOpenUpState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerOpenUpState_hpp */
