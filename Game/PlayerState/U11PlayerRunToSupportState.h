//
//  U11PlayerRunToSupportState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerRunToSupportState_hpp
#define U11PlayerRunToSupportState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerRunToSupportState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerRunToSupportState();
    
    ~U11PlayerRunToSupportState();
    
public:
    
    static U11PlayerRunToSupportState* instance;
    
    static U11PlayerRunToSupportState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerRunToSupportState_hpp */
