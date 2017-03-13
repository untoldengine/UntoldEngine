//
//  U11PlayerRunPassState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/12/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerRunPassState_hpp
#define U11PlayerRunPassState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerRunPassState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerRunPassState();
    
    ~U11PlayerRunPassState();
    
public:
    
    static U11PlayerRunPassState* instance;
    
    static U11PlayerRunPassState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerRunPassState_hpp */
