//
//  U11TeamAttackingState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11TeamAttackingState_hpp
#define U11TeamAttackingState_hpp

#include <stdio.h>
#include "UserCommonProtocols.h"
#include "U11TeamStateInterface.h"

class U11Team;

class U11TeamAttackingState:public U11TeamStateInterface {

private:
    
    U11TeamAttackingState();
    
    ~U11TeamAttackingState();
    
public:
    
    static U11TeamAttackingState *instance;
    
    static U11TeamAttackingState *sharedInstance();
    
    void enter(U11Team *uTeam);
    
    void execute(U11Team *uTeam, double dt);
    
    void exit(U11Team *uTeam);
    
    bool handleMessage(U11Team *uTeam, Message &uMsg);
};

#endif /* U11TeamAttackingState_hpp */
