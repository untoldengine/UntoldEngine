//
//  U11PlayerRunToDefendState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerRunToDefendState_hpp
#define U11PlayerRunToDefendState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerRunToDefendState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerRunToDefendState();
    
    ~U11PlayerRunToDefendState();
    
public:
    
    static U11PlayerRunToDefendState* instance;
    
    static U11PlayerRunToDefendState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerRunToDefendState_hpp */
