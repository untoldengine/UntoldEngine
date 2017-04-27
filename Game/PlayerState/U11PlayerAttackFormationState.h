//
//  U11PlayerAttackFormationState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/26/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerAttackFormationState_hpp
#define U11PlayerAttackFormationState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerAttackFormationState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerAttackFormationState();
    
    ~U11PlayerAttackFormationState();
    
public:
    
    static U11PlayerAttackFormationState* instance;
    
    static U11PlayerAttackFormationState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerAttackFormationState_hpp */
