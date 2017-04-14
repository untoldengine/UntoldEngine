//
//  U11PlayerDefendState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerDefendState_hpp
#define U11PlayerDefendState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerDefendState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerDefendState();
    
    ~U11PlayerDefendState();
    
public:
    
    static U11PlayerDefendState* instance;
    
    static U11PlayerDefendState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerDefendState_hpp */
