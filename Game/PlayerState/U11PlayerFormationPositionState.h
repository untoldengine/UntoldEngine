//
//  U11PlayerFormationPositionState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerFormationPositionState_hpp
#define U11PlayerFormationPositionState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerFormationPositionState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerFormationPositionState();
    
    ~U11PlayerFormationPositionState();
    
public:
    
    static U11PlayerFormationPositionState* instance;
    
    static U11PlayerFormationPositionState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerFormationPositionState_hpp */
