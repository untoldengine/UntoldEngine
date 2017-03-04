//
//  U11PlayerIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerIdleState_hpp
#define U11PlayerIdleState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerIdleState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerIdleState();
    
    ~U11PlayerIdleState();
    
public:
    
    static U11PlayerIdleState* instance;
    
    static U11PlayerIdleState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
};
#endif /* U11PlayerIdleState_hpp */
