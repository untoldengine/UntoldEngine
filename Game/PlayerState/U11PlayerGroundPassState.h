//
//  U11PlayerGroundPassState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerGroundPassState_hpp
#define U11PlayerGroundPassState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerGroundPassState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerGroundPassState();
    
    ~U11PlayerGroundPassState();
    
public:
    
    static U11PlayerGroundPassState* instance;
    
    static U11PlayerGroundPassState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerGroundPassState_hpp */
