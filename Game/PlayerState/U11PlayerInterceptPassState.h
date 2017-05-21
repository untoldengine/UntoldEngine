//
//  U11PlayerInterceptPassState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerInterceptPassState_hpp
#define U11PlayerInterceptPassState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerInterceptPassState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerInterceptPassState();
    
    ~U11PlayerInterceptPassState();
    
public:
    
    static U11PlayerInterceptPassState* instance;
    
    static U11PlayerInterceptPassState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerInterceptPassState_hpp */
