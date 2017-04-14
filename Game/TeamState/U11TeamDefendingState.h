//
//  U11TeamDefendingState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11TeamDefendingState_hpp
#define U11TeamDefendingState_hpp

#include <stdio.h>
#include "UserCommonProtocols.h"
#include "U11TeamStateInterface.h"

class U11Team;

class U11TeamDefendingState:public U11TeamStateInterface {
    
private:
    
    U11TeamDefendingState();
    
    ~U11TeamDefendingState();
    
public:
    
    static U11TeamDefendingState *instance;
    
    static U11TeamDefendingState *sharedInstance();
    
    void enter(U11Team *uTeam);
    
    void execute(U11Team *uTeam, double dt);
    
    void exit(U11Team *uTeam);
    
    bool handleMessage(U11Team *uTeam, Message &uMsg);
};
#endif /* U11TeamDefendingState_hpp */
