//
//  U11PlayerAttackState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerAttackState_hpp
#define U11PlayerAttackState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerAttackState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerAttackState();
    
    ~U11PlayerAttackState();
    
public:
    
    static U11PlayerAttackState* instance;
    
    static U11PlayerAttackState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerAttackState_hpp */
