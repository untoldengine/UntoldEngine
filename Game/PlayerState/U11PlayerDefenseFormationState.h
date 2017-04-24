//
//  U11PlayerFormationSpace.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/24/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerDefenseFormationState_hpp
#define U11PlayerDefenseFormationState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerDefenseFormationState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerDefenseFormationState();
    
    ~U11PlayerDefenseFormationState();
    
public:
    
    static U11PlayerDefenseFormationState* instance;
    
    static U11PlayerDefenseFormationState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerFormationSpace_hpp */
