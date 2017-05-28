//
//  U11PlayerInterceptState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerInterceptState_hpp
#define U11PlayerInterceptState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerInterceptState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerInterceptState();
    
    ~U11PlayerInterceptState();
    
public:
    
    static U11PlayerInterceptState* instance;
    
    static U11PlayerInterceptState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerInterceptPassState_hpp */
