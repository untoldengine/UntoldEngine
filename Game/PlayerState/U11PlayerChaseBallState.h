//
//  U11PlayerChaseBallState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerChaseBallState_hpp
#define U11PlayerChaseBallState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerChaseBallState:public U11PlayerStateInterface {
    
private:
    
protected:
    
    U11PlayerChaseBallState();
    
    ~U11PlayerChaseBallState();
    
public:
    
    static U11PlayerChaseBallState* instance;
    
    static U11PlayerChaseBallState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
};

#endif /* U11PlayerChaseBallState_hpp */
