//
//  U11PlayerHomePositionState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/13/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerHomePositionState_hpp
#define U11PlayerHomePositionState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerHomePositionState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerHomePositionState();
    
    ~U11PlayerHomePositionState();
    
public:
    
    static U11PlayerHomePositionState* instance;
    
    static U11PlayerHomePositionState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerHomePositionState_hpp */
